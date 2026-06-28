import CoreLocation
import MobiIOSDependencies
import SwiftUI
import UIKit

struct NearbyVehicleMapRenderer: UIViewRepresentable {
    let scene: NearbyVehicleMapScene?
    let styleURL: URL

    init(
        scene: NearbyVehicleMapScene?,
        styleURL: URL = NearbyVehicleMapBasemapConfig.defaultStyleURL,
    ) {
        self.scene = scene
        self.styleURL = styleURL
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.delegate = context.coordinator
        mapView.logoView.isHidden = false
        mapView.attributionButton.isHidden = false
        mapView.compassView.isHidden = false
        render(scene: scene, in: mapView)
        return mapView
    }

    func updateUIView(
        _ mapView: MLNMapView,
        context: Context,
    ) {
        mapView.delegate = context.coordinator
        if mapView.styleURL != styleURL {
            mapView.styleURL = styleURL
        }
        render(scene: scene, in: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func render(
        scene: NearbyVehicleMapScene?,
        in mapView: MLNMapView,
    ) {
        let camera = scene?.camera ?? Self.defaultCamera
        mapView.setCenter(
            camera.target.locationCoordinate,
            zoomLevel: camera.zoom,
            animated: false,
        )

        if let annotations = mapView.annotations, !annotations.isEmpty {
            mapView.removeAnnotations(annotations)
        }

        guard let scene else { return }

        var annotations: [MLNPointAnnotation] = []
        let riderAnnotation = MLNPointAnnotation()
        riderAnnotation.coordinate = scene.riderMarker.coordinate.locationCoordinate
        riderAnnotation.title = "Rider"
        annotations.append(riderAnnotation)

        annotations.append(
            contentsOf: scene.vehicleMarkers.map { marker in
                let annotation = MLNPointAnnotation()
                annotation.coordinate = marker.coordinate.locationCoordinate
                annotation.title = marker.id
                return annotation
            },
        )
        mapView.addAnnotations(annotations)
    }

    private static let defaultCamera =
        NearbyVehicleMapCamera(
            target: NearbyVehicleMapCoordinate(
                latitude: 55.6761,
                longitude: 12.5683,
            ),
            zoom: 12,
        )
}

extension NearbyVehicleMapRenderer {
    final class Coordinator: NSObject, MLNMapViewDelegate {
        func mapView(
            _ mapView: MLNMapView,
            viewFor annotation: MLNAnnotation,
        ) -> MLNAnnotationView? {
            guard annotation is MLNPointAnnotation else { return nil }

            let isRider = annotation.title == "Rider"
            let reuseIdentifier = isRider ? "nearby-rider-marker" : "nearby-vehicle-marker"

            return MainActor.assumeIsolated {
                NearbyVehicleMapAnnotationView(
                    reuseIdentifier: reuseIdentifier,
                    isRider: isRider,
                )
            }
        }
    }
}

private final class NearbyVehicleMapAnnotationView: MLNAnnotationView {
    init(
        reuseIdentifier: String,
        isRider: Bool,
    ) {
        super.init(reuseIdentifier: reuseIdentifier)
        configure(isRider: isRider)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func configure(isRider: Bool) {
        let diameter: CGFloat = isRider ? 18 : 16
        frame = CGRect(
            x: 0,
            y: 0,
            width: diameter,
            height: diameter,
        )
        backgroundColor =
            isRider
                ? UIColor(red: 0.05, green: 0.37, blue: 0.25, alpha: 1)
                : UIColor(red: 0.85, green: 0.48, blue: 0.21, alpha: 1)
        layer.cornerRadius = diameter / 2
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = isRider ? 3 : 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }
}

private extension NearbyVehicleMapCoordinate {
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude,
        )
    }
}
