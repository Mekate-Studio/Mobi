@testable import app
import ComposableArchitecture
import Foundation
@preconcurrency import KotlinModules
import Testing

@Suite("NearbyVehicleMapFeature")
struct NearbyVehicleMapFeatureTests {
    @MainActor
    @Test("should have resolving rider location when task is sent")
    func shouldHaveResolvingRiderLocationWhenTaskIsSent() async {
        // given
        let store = NearbyVehicleMapFeatureTestFactory.makeStore()

        // when
        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }

        // then
        #expect(store.state.message == "Grant while-in-use location access to center discovery around the rider.")
        #expect(store.state.overlay == .none)
    }

    @MainActor
    @Test("should wire denied permission into blocking overlay")
    func shouldWireDeniedPermissionIntoBlockingOverlay() async {
        // given
        let store = NearbyVehicleMapFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }

        // when
        await store.send(.locationPermissionResponse(.denied)) {
            $0 = NearbyVehicleMapFeatureTestFactory.deniedState()
        }

        // then
        #expect(store.state.overlay == .blockingFailure)
        #expect(store.state.canRequestRefresh == false)
    }

    @MainActor
    @Test("should load rider centered snapshot after permission is granted")
    func shouldLoadRiderCenteredSnapshotAfterPermissionIsGranted() async {
        // given
        let store = NearbyVehicleMapFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }

        await store.send(.locationPermissionResponse(.granted)) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }

        // when / then
        await store.receive(.sharedStateLoaded(NearbyVehicleMapFeatureTestFactory.loadedState())) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadedState()
        }
    }

    @MainActor
    @Test("should request visible refresh when refresh is due")
    func shouldRequestVisibleRefreshWhenRefreshIsDue() async {
        // given
        let store = NearbyVehicleMapFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }
        await store.send(.locationPermissionResponse(.granted)) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }
        await store.receive(.sharedStateLoaded(NearbyVehicleMapFeatureTestFactory.loadedState())) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadedState()
        }

        // when
        await store.send(.visibleRefreshDue(nowMillis: 11000)) {
            $0 = NearbyVehicleMapFeatureTestFactory.refreshingState()
        }

        // then
        await store.receive(.sharedStateLoaded(NearbyVehicleMapFeatureTestFactory.loadedState(sequence: 2))) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadedState(sequence: 2)
        }
    }

    @MainActor
    @Test("should keep last rider location when live location becomes temporarily unavailable")
    func shouldKeepLastRiderLocationWhenLiveLocationBecomesTemporarilyUnavailable() async {
        // given
        let store = NearbyVehicleMapFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }
        await store.send(.locationPermissionResponse(.granted)) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }
        await store.receive(.sharedStateLoaded(NearbyVehicleMapFeatureTestFactory.loadedState())) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadedState()
        }

        // when
        await store.send(.locationPermissionResponse(.temporarilyUnavailable)) {
            $0 = NearbyVehicleMapFeatureTestFactory.temporarilyUnavailableState()
        }

        // then
        guard case let .riderCentered(scene) = store.state.mapContent else {
            #expect(Bool(false), "Expected map content to keep the last rider-centered coordinate.")
            return
        }
        let riderLocation = scene.riderMarker.coordinate
        #expect(riderLocation.latitude == 55.6761)
        #expect(riderLocation.longitude == 12.5683)
    }

    @MainActor
    @Test("should map loaded shared state into provider neutral map scene")
    func shouldMapLoadedSharedStateIntoProviderNeutralMapScene() {
        // given
        let state = NearbyVehicleMapFeatureTestFactory.loadedState()

        // when / then
        guard case let .riderCentered(scene) = state.mapContent else {
            #expect(Bool(false), "Expected loaded shared state to produce a rider-centered map scene.")
            return
        }
        #expect(scene.camera.target.latitude == 55.6761)
        #expect(scene.camera.target.longitude == 12.5683)
        #expect(scene.camera.zoom == 15)
        #expect(scene.riderMarker.coordinate == scene.camera.target)
        #expect(scene.vehicleMarkers.map(\.id) == ["mobi-ios-001"])
        #expect(scene.vehicleMarkers.single?.coordinate.latitude == 55.6764)
        #expect(scene.vehicleMarkers.single?.coordinate.longitude == 12.5687)
    }

    @MainActor
    @Test("should emit empty vehicle markers while rider is visible before snapshot loads")
    func shouldEmitEmptyVehicleMarkersBeforeSnapshotLoads() {
        // given
        let state = NearbyVehicleMapFeatureTestFactory.loadingState()

        // when / then
        guard case let .riderCentered(scene) = state.mapContent else {
            #expect(Bool(false), "Expected visible rider state to produce a rider-centered map scene.")
            return
        }
        #expect(scene.vehicleMarkers.isEmpty)
    }

    @MainActor
    @Test("should preserve blocking overlay separately from map content")
    func shouldPreserveBlockingOverlaySeparatelyFromMapContent() {
        // given
        let state = NearbyVehicleMapFeatureTestFactory.deniedState()

        // when / then
        #expect(state.mapContent == .waitingForRider)
        #expect(state.overlay == .blockingFailure)
    }
}

private extension Collection {
    var single: Element? {
        count == 1 ? first : nil
    }
}

private enum NearbyVehicleMapFeatureTestFactory {
    @MainActor
    static func makeStore() -> TestStore<NearbyVehicleMapFeature.State, NearbyVehicleMapFeature.Action> {
        TestStore(initialState: NearbyVehicleMapFeature.State()) {
            NearbyVehicleMapFeature()
        } withDependencies: {
            $0.nearbyVehicleMapFeatureClient = makeClient()
        }
    }

    static func makeClient() -> NearbyVehicleMapFeatureClient {
        NearbyVehicleMapFeatureClient(
            initialState: {
                makeSharedState(
                    riderLocationState: RiderLocationStateResolving.shared,
                    snapshotState: NearbyVehicleSnapshotStateInitial.shared,
                    overlayState: NearbyVehicleMapOverlayStateNone.shared,
                )
            },
            permissionGrantedState: { currentState in
                makeSharedState(
                    riderLocationState: RiderLocationStateAvailable(location: riderLocation()),
                    snapshotState: currentState.snapshotState,
                    overlayState: currentState.mapOverlayState,
                )
            },
            permissionDeniedState: { _ in
                deniedSharedState()
            },
            locationTemporarilyUnavailableState: { currentState in
                makeSharedState(
                    riderLocationState: RiderLocationStateTemporarilyUnavailable(location: riderLocation()),
                    snapshotState: currentState.snapshotState,
                    overlayState: currentState.mapOverlayState,
                )
            },
            loadingState: { currentState in
                let snapshot = currentSnapshot(from: currentState.snapshotState)
                return makeSharedState(
                    riderLocationState: currentState.riderLocationState,
                    snapshotState: snapshot
                        .map { NearbyVehicleSnapshotStateRefreshing(snapshot: $0) } ?? NearbyVehicleSnapshotStateLoading
                        .shared,
                    overlayState: snapshot == nil ? NearbyVehicleMapOverlayStateNone
                        .shared : NearbyVehicleMapOverlayStateRefreshingIndicator.shared,
                )
            },
            refresh: { currentState, _ in
                await Task.yield()
                let sequence = currentSnapshot(from: currentState.snapshotState).map { $0.sequence + 1 } ?? 1
                return loadedSharedState(sequence: sequence)
            },
            shouldRefresh: { currentState, nowMillis in
                guard let snapshot = currentSnapshot(from: currentState.snapshotState) else { return false }
                return nowMillis - snapshot.loadedAtMillis >= 10000
            },
        )
    }

    static func initialState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: RiderLocationStateResolving.shared,
                snapshotState: NearbyVehicleSnapshotStateInitial.shared,
                overlayState: NearbyVehicleMapOverlayStateNone.shared,
            ),
        )
        return state
    }

    static func loadingState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: RiderLocationStateAvailable(location: riderLocation()),
                snapshotState: NearbyVehicleSnapshotStateLoading.shared,
                overlayState: NearbyVehicleMapOverlayStateNone.shared,
            ),
        )
        return state
    }

    static func refreshingState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: RiderLocationStateAvailable(location: riderLocation()),
                snapshotState: NearbyVehicleSnapshotStateRefreshing(snapshot: snapshot()),
                overlayState: NearbyVehicleMapOverlayStateRefreshingIndicator.shared,
            ),
        )
        return state
    }

    static func loadedState(sequence: Int64 = 1) -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: loadedSharedState(sequence: sequence))
        return state
    }

    static func deniedState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: deniedSharedState())
        return state
    }

    static func temporarilyUnavailableState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: RiderLocationStateTemporarilyUnavailable(location: riderLocation()),
                snapshotState: NearbyVehicleSnapshotStateLoaded(snapshot: snapshot()),
                overlayState: NearbyVehicleMapOverlayStateNone.shared,
            ),
        )
        return state
    }

    static func loadedSharedState(sequence: Int64 = 1) -> NearbyVehicleMapFeatureState {
        makeSharedState(
            riderLocationState: RiderLocationStateAvailable(location: riderLocation()),
            snapshotState: NearbyVehicleSnapshotStateLoaded(snapshot: snapshot(sequence: sequence)),
            overlayState: NearbyVehicleMapOverlayStateNone.shared,
        )
    }

    static func deniedSharedState() -> NearbyVehicleMapFeatureState {
        makeSharedState(
            riderLocationState: RiderLocationStateDenied.shared,
            snapshotState: NearbyVehicleSnapshotStateFailedWithoutSnapshot(
                reason: NearbyVehicleMapFailureReason.riderLocationUnavailable,
            ),
            overlayState: NearbyVehicleMapOverlayStateBlockingFailure.shared,
        )
    }

    static func makeSharedState(
        riderLocationState: RiderLocationState,
        snapshotState: NearbyVehicleSnapshotState,
        overlayState: NearbyVehicleMapOverlayState,
    ) -> NearbyVehicleMapFeatureState {
        NearbyVehicleMapFeatureState(
            riderLocationState: riderLocationState,
            snapshotState: snapshotState,
            mapOverlayState: overlayState,
        )
    }

    static func currentSnapshot(from state: NearbyVehicleSnapshotState) -> FleetSnapshot? {
        switch onEnum(of: state) {
        case .initial, .loading:
            nil
        case let .loaded(state):
            state.snapshot
        case let .refreshing(state):
            state.snapshot
        case let .failedWithSnapshot(state):
            state.snapshot
        case .failedWithoutSnapshot:
            nil
        }
    }

    static func snapshot(sequence: Int64 = 1) -> FleetSnapshot {
        FleetSnapshot(
            sequence: sequence,
            riderLocation: riderLocation(),
            vehicles: [
                NearbyVehicle(
                    id: "mobi-ios-001",
                    location: VehicleLocation(latitude: 55.6764, longitude: 12.5687),
                ),
            ],
            loadedAtMillis: 1000,
        )
    }

    static func riderLocation() -> RiderLocation {
        RiderLocation(latitude: 55.6761, longitude: 12.5683)
    }
}
