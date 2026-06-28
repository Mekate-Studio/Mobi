import Combine
import CoreLocation
import Foundation

@MainActor
final class NearbyVehicleMapLocationClient: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var completion: ((NearbyVehicleMapFeature.LocationResolutionResult) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPreciseLocation(
        completion: @escaping (NearbyVehicleMapFeature.LocationResolutionResult) -> Void,
    ) {
        self.completion = completion

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestCurrentPreciseLocation()
        case .denied:
            complete(.blocked(.accessDenied))
        case .restricted:
            complete(.blocked(.accessRestricted))
        @unknown default:
            complete(.blocked(.accessRestricted))
        }
    }

    private func requestCurrentPreciseLocation() {
        guard locationManager.accuracyAuthorization == .fullAccuracy else {
            complete(.blocked(.approximateOnly))
            return
        }

        locationManager.requestLocation()
    }

    private func complete(_ result: NearbyVehicleMapFeature.LocationResolutionResult) {
        completion?(result)
        completion = nil
    }
}

extension NearbyVehicleMapLocationClient: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorizationStatus = manager.authorizationStatus

        Task { @MainActor in
            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                requestCurrentPreciseLocation()
            case .denied:
                complete(.blocked(.accessDenied))
            case .restricted:
                complete(.blocked(.accessRestricted))
            case .notDetermined:
                break
            @unknown default:
                complete(.blocked(.accessRestricted))
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation],
    ) {
        guard let location = locations.last else {
            Task { @MainActor in complete(.temporarilyUnavailable) }
            return
        }

        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        Task { @MainActor in
            complete(
                .precise(
                    latitude: latitude,
                    longitude: longitude,
                ),
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error,
    ) {
        let result: NearbyVehicleMapFeature.LocationResolutionResult =
            if let locationError = error as? CLError, locationError.code == .denied {
                .blocked(.servicesDisabled)
            } else {
                .temporarilyUnavailable
            }

        Task { @MainActor in complete(result) }
    }
}
