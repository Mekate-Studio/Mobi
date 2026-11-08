@testable import app
import KotlinRuntime
import MobiCore
import MobiNearby
import Testing

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
    @MainActor
    @Test(
        "should preserve Swift repository failures and retained Nearby content",
        .timeLimit(.minutes(1)),
        arguments: [false, true],
    )
    func shouldPreserveSwiftRepositoryFailuresAndRetainedContent(hasSnapshot: Bool) async throws {
        // given
        let previous = hasSnapshot
            ? NearbyVehicleMapFeatureTestFactory.loadedState()
            : NearbyVehicleMapFeatureTestFactory.readyState()
        let retained = try #require(previous.sharedState)
        let snapshot = NearbyVehicleMapFeatureTestFactory.currentSnapshot(from: retained.snapshotState)
        let service = NearbyVehicleMapFeatureService(
            nearbyFleetRepository: SwiftNearbyFleetRepository(failure: .unexpected),
            freshnessPolicy: NearbyVehicleMapFreshnessPolicy(),
        )
        let loading = service.loadingState(currentState: retained)
        let expected: any NearbyVehicleSnapshotState = if let snapshot {
            NearbyVehicleSnapshotState.FailedWithSnapshot(snapshot: snapshot, reason: .Unexpected)
        } else {
            NearbyVehicleSnapshotState.FailedWithoutSnapshot(reason: .Unexpected)
        }
        let nowMillis: Int64 = 11000

        // when: a thrown bridge error must fail here, before the native client's fallback.
        let sharedFailure = try await service.refreshSnapshot(currentState: loading, nowMillis: nowMillis)

        // then
        #expect(sharedFailure.snapshotState == expected)
        #expect(sharedFailure.riderLocationState == retained.riderLocationState)

        // when
        let client = NearbyVehicleMapFeatureClient(service: service)
        let nativeFailure = await client.refresh(loading, nowMillis)
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: nativeFailure)

        // then
        #expect(nativeFailure == sharedFailure)
        #expect(state.mapContent == previous.mapContent)
        #expect(state.hasResolvedRiderLocation)
        #expect(state.canRequestRefresh)
        #expect(state.canInteractWithVehicles == hasSnapshot)
        if hasSnapshot {
            #expect(state.overlay == .stale)
        } else {
            #expect(state.overlay == .blocking(
                headline: "Map unavailable",
                message: "Something went wrong while loading nearby vehicles. Try refreshing again.",
            ))
        }
    }

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

private enum NearbyRepositoryTestError: Error {
    case unexpected
}

private final class SwiftNearbyFleetRepository: KotlinBase, NearbyFleetRepository {
    private let failure: NearbyRepositoryTestError?

    init(failure: NearbyRepositoryTestError? = nil) {
        self.failure = failure
        super.init()
    }

    func fetchNearbyFleetSnapshot(request: NearbyFleetRequest) async throws -> FleetSnapshot {
        if let failure {
            throw failure
        }
        return FleetSnapshot(
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
