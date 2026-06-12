import CoreLocation
import MapLibre
import SwiftUI

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

    func makeUIView(context _: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.logoView.isHidden = false
        mapView.attributionButton.isHidden = false
        mapView.compassView.isHidden = false
        render(scene: scene, in: mapView)
        return mapView
    }

    func updateUIView(
        _ mapView: MLNMapView,
        context _: Context,
    ) {
        if mapView.styleURL != styleURL {
            mapView.styleURL = styleURL
        }
        render(scene: scene, in: mapView)
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

private extension NearbyVehicleMapCoordinate {
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude,
        )
    }
}
