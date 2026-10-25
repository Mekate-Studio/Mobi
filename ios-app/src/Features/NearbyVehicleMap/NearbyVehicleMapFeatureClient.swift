import Foundation
@preconcurrency import MobiCore
import MobiIOSDependencies
@preconcurrency import MobiNearby

extension NearbyVehicleMapFeatureState: @unchecked @retroactive Sendable {}

struct NearbyVehicleMapFeatureClient {
    var initialState: @Sendable () -> NearbyVehicleMapFeatureState
    var preciseLocationResolvedState: @Sendable (
        _ currentState: NearbyVehicleMapFeatureState,
        _ latitude: Double,
        _ longitude: Double,
    ) -> NearbyVehicleMapFeatureState
    var locationBlockedState: @Sendable (
        _ currentState: NearbyVehicleMapFeatureState,
        _ reason: NearbyVehicleMapFeature.LocationBlockedReason,
    ) -> NearbyVehicleMapFeatureState
    var locationTemporarilyUnavailableState: @Sendable (_ currentState: NearbyVehicleMapFeatureState)
        -> NearbyVehicleMapFeatureState
    var loadingState: @Sendable (_ currentState: NearbyVehicleMapFeatureState) -> NearbyVehicleMapFeatureState
    var refresh: @Sendable (_ currentState: NearbyVehicleMapFeatureState, _ nowMillis: Int64) async
        -> NearbyVehicleMapFeatureState
    var shouldRefresh: @Sendable (_ currentState: NearbyVehicleMapFeatureState, _ nowMillis: Int64) -> Bool
    var stateAfterTimePasses: @Sendable (
        _ currentState: NearbyVehicleMapFeatureState,
        _ nowMillis: Int64,
    ) -> NearbyVehicleMapFeatureState
}

extension NearbyVehicleMapFeatureClient {
    init(service: NearbyVehicleMapFeatureService) {
        self.init(
            initialState: {
                service.initialState()
            },
            preciseLocationResolvedState: { currentState, latitude, longitude in
                service.riderLocationAvailable(
                    currentState: currentState,
                    location: RiderLocation(latitude: latitude, longitude: longitude),
                )
            },
            locationBlockedState: { currentState, reason in
                service.riderLocationBlocked(
                    currentState: currentState,
                    reason: reason.sharedReason,
                )
            },
            locationTemporarilyUnavailableState: { currentState in
                service.riderLocationTemporarilyUnavailable(currentState: currentState)
            },
            loadingState: { currentState in
                service.loadingState(currentState: currentState)
            },
            refresh: { currentState, nowMillis in
                do {
                    return try await service.refreshSnapshot(
                        currentState: currentState,
                        nowMillis: nowMillis,
                    )
                } catch is CancellationError {
                    return cancelledRefreshState(currentState)
                } catch {
                    return service.failedState(
                        currentState: currentState,
                        reason: .Unexpected,
                        nowMillis: nowMillis,
                    )
                }
            },
            shouldRefresh: { currentState, nowMillis in
                service.shouldRefresh(
                    currentState: currentState,
                    nowMillis: nowMillis,
                )
            },
            stateAfterTimePasses: { currentState, nowMillis in
                service.stateAfterTimePasses(currentState: currentState, nowMillis: nowMillis)
            },
        )
    }
}

extension NearbyVehicleMapFeatureClient: DependencyKey {
    static let liveValue = NearbyVehicleMapFeatureClient(
        initialState: {
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        preciseLocationResolvedState: { _, _, _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        locationBlockedState: { _, _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        locationTemporarilyUnavailableState: { _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        loadingState: { _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        refresh: { _, _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        shouldRefresh: { _, _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        stateAfterTimePasses: { _, _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
    )
}

extension DependencyValues {
    var nearbyVehicleMapFeatureClient: NearbyVehicleMapFeatureClient {
        get { self[NearbyVehicleMapFeatureClient.self] }
        set { self[NearbyVehicleMapFeatureClient.self] = newValue }
    }
}

private extension NearbyVehicleMapFeature.LocationBlockedReason {
    var sharedReason: RiderLocationBlockedReason {
        switch self {
        case .accessDenied:
            .AccessDenied
        case .accessRestricted:
            .AccessRestricted
        case .servicesDisabled:
            .ServicesDisabled
        case .approximateOnly:
            .ApproximateOnly
        case .temporarilyUnavailable:
            .TemporarilyUnavailable
        }
    }
}
