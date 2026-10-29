import CoreLocation
import MobiIOSDependencies

struct NearbyVehicleMapLocationClient {
    typealias Result = NearbyVehicleMapFeature.LocationResolutionResult
    var resolve: @Sendable () async -> Result?

    static func firstResult<Updates: AsyncSequence>(
        in updates: Updates,
    ) async -> Result? where Updates.Element == Result? {
        guard !Task.isCancelled else { return nil }
        do {
            for try await result in updates {
                guard !Task.isCancelled else { return nil }
                if let result {
                    return result
                }
            }
        } catch {
            return Task.isCancelled ? nil : .temporarilyUnavailable
        }
        return Task.isCancelled ? nil : .temporarilyUnavailable
    }

    private static func result(for update: CLLocationUpdate) -> Result? {
        if update.authorizationDeniedGlobally {
            return .blocked(.servicesDisabled)
        }
        if update.authorizationRestricted {
            return .blocked(.accessRestricted)
        }
        if update.authorizationDenied {
            return .blocked(.accessDenied)
        }
        if update.accuracyLimited {
            return .blocked(.approximateOnly)
        }
        if update.authorizationRequestInProgress || update.insufficientlyInUse {
            return nil
        }
        if let location = update.location {
            return .precise(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        return update.locationUnavailable ? .temporarilyUnavailable : nil
    }
}

extension NearbyVehicleMapLocationClient: DependencyKey {
    static let liveValue = Self {
        guard !Task.isCancelled else { return nil }
        return await firstResult(in: CLLocationUpdate.liveUpdates().map { result(for: $0) })
    }

    static let testValue = Self { nil }
}

extension DependencyValues {
    var nearbyVehicleMapLocationClient: NearbyVehicleMapLocationClient {
        get { self[NearbyVehicleMapLocationClient.self] }
        set { self[NearbyVehicleMapLocationClient.self] = newValue }
    }
}
