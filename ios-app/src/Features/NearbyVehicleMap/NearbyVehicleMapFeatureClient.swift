import ComposableArchitecture
import Foundation
@preconcurrency import KotlinModules

extension NearbyVehicleMapFeatureState: @unchecked @retroactive Sendable {}

struct NearbyVehicleMapFeatureClient {
    var initialState: @Sendable () -> NearbyVehicleMapFeatureState
    var permissionGrantedState: @Sendable (_ currentState: NearbyVehicleMapFeatureState) -> NearbyVehicleMapFeatureState
    var permissionDeniedState: @Sendable (_ currentState: NearbyVehicleMapFeatureState) -> NearbyVehicleMapFeatureState
    var locationTemporarilyUnavailableState: @Sendable (_ currentState: NearbyVehicleMapFeatureState)
        -> NearbyVehicleMapFeatureState
    var loadingState: @Sendable (_ currentState: NearbyVehicleMapFeatureState) -> NearbyVehicleMapFeatureState
    var refresh: @Sendable (_ currentState: NearbyVehicleMapFeatureState, _ nowMillis: Int64) async
        -> NearbyVehicleMapFeatureState
    var shouldRefresh: @Sendable (_ currentState: NearbyVehicleMapFeatureState, _ nowMillis: Int64) -> Bool
}

extension NearbyVehicleMapFeatureClient {
    init(service: NearbyVehicleMapFeatureService) {
        self.init(
            initialState: {
                service.initialState()
            },
            permissionGrantedState: { currentState in
                service.riderLocationAvailable(
                    currentState: currentState,
                    location: RiderLocation(latitude: 55.6761, longitude: 12.5683),
                )
            },
            permissionDeniedState: { currentState in
                service.riderLocationDenied(currentState: currentState)
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
                } catch {
                    return currentState
                }
            },
            shouldRefresh: { currentState, nowMillis in
                service.shouldRefresh(
                    currentState: currentState,
                    nowMillis: nowMillis,
                )
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
        permissionGrantedState: { _ in
            fatalError(
                "NearbyVehicleMapFeatureClient.liveValue was used without AppServices injecting dependencies. Create stores through AppServices so iOS has a single composition root.",
            )
        },
        permissionDeniedState: { _ in
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
    )
}

extension DependencyValues {
    var nearbyVehicleMapFeatureClient: NearbyVehicleMapFeatureClient {
        get { self[NearbyVehicleMapFeatureClient.self] }
        set { self[NearbyVehicleMapFeatureClient.self] = newValue }
    }
}
