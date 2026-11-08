@testable import app
import KotlinRuntime
import MobiCore
import MobiNearby
import Testing

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
    @MainActor
    @Test(
        "should load a Swift repository snapshot through the Kotlin service and native client",
        .timeLimit(.minutes(1)),
    )
    func shouldLoadSwiftRepositorySnapshotThroughSharedServiceAndNativeClient() async throws {
        // given
        let service = NearbyVehicleMapFeatureService(
            nearbyFleetRepository: SwiftNearbyFleetRepository(),
            freshnessPolicy: NearbyVehicleMapFreshnessPolicy(),
        )
        let rider = RiderLocation(latitude: 56, longitude: 13)
        let ready = service.riderLocationAvailable(currentState: service.initialState(), location: rider)
        let loading = service.loadingState(currentState: ready)
        let nowMillis: Int64 = 21000

        // when: qualify the service result before the native client's fallback can interpret it.
        let sharedResult = try await service.refreshSnapshot(currentState: loading, nowMillis: nowMillis)

        // then
        guard case let .loaded(loaded) = sharedResult.snapshotState.sealedType() else {
            Issue.record("The Kotlin service must load the Swift repository's snapshot")
            return
        }
        let snapshot = loaded.value.snapshot
        #expect(snapshot.sequence == 41)
        #expect(snapshot.riderLocation == rider)
        #expect(snapshot.loadedAtMillis == nowMillis)
        #expect(snapshot.vehicles.map(\.id.value) == ["swift-nearby-001"])

        // when: use the same real service through the maintained native client.
        let client = NearbyVehicleMapFeatureClient(service: service)
        let nativeResult = await client.refresh(loading, nowMillis)
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: nativeResult)

        // then
        #expect(nativeResult == sharedResult)
        #expect(state.overlay == .none)
        #expect(state.canRequestRefresh)
        #expect(state.canInteractWithVehicles)
        guard case let .riderCentered(scene) = state.mapContent else {
            Issue.record("The Swift repository result must produce a rider-centered map")
            return
        }
        #expect(scene.camera.target == NearbyVehicleMapCoordinate(latitude: 56, longitude: 13))
        #expect(scene.riderMarker.coordinate == scene.camera.target)
        #expect(scene.vehicleMarkers.map(\.id) == ["swift-nearby-001"])
        #expect(scene.vehicleMarkers.first?.coordinate == NearbyVehicleMapCoordinate(latitude: 56.25, longitude: 13.5))
    }
}

private final class SwiftNearbyFleetRepository: KotlinBase, NearbyFleetRepository {
    func fetchNearbyFleetSnapshot(request: NearbyFleetRequest) async throws -> FleetSnapshot {
        FleetSnapshot(
            sequence: 41,
            riderLocation: request.riderLocation,
            vehicles: [
                NearbyVehicle(
                    id: VehicleId(value: "swift-nearby-001"),
                    location: VehicleLocation(
                        latitude: request.riderLocation.latitude + 0.25,
                        longitude: request.riderLocation.longitude + 0.5,
                    ),
                ),
            ],
            loadedAtMillis: request.requestedAtMillis,
        )
    }
}
