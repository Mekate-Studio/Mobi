// The scenarios intentionally share one explicit factory so native/shared state mappings remain visible together.
// swiftlint:disable file_length
@testable import app
import Foundation
@preconcurrency import MobiCore
import MobiIOSDependencies
@preconcurrency import MobiNearby
import MobiTestSupport
import Testing

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
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
        await store.send(.locationResolutionResponse(.blocked(.accessDenied))) {
            $0 = NearbyVehicleMapFeatureTestFactory.deniedState()
        }

        // then
        #expect(store.state.overlay == .blockingFailure)
        #expect(store.state.canRequestRefresh == false)
        #expect(store.state.canInteractWithVehicles == false)
    }

    @MainActor
    @Test("should keep location blocked when an earlier refresh completes")
    func shouldKeepLocationBlockedWhenEarlierRefreshCompletes() async {
        // given
        let completion = AsyncStream<Void>.makeStream()
        var client = NearbyVehicleMapFeatureTestFactory.makeClient()
        client.refresh = { _, _ in
            for await _ in completion.stream {
                break
            }
            return NearbyVehicleMapFeatureTestFactory.loadedSharedState()
        }
        let store = NearbyVehicleMapFeatureTestFactory.makeStore(client: client)
        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }
        await store.send(.locationResolutionResponse(.precise(latitude: 55.6761, longitude: 12.5683))) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }

        // when
        await store.send(.locationResolutionResponse(.blocked(.accessDenied))) {
            $0 = NearbyVehicleMapFeatureTestFactory.deniedState()
        }
        completion.continuation.yield(())
        completion.continuation.finish()
        await store.receive(.sharedStateLoaded(NearbyVehicleMapFeatureTestFactory.loadedState()))

        // then
        #expect(store.state.mapContent == .waitingForRider)
        #expect(store.state.overlay == .blockingFailure)
        #expect(store.state.canInteractWithVehicles == false)
    }

    @MainActor
    @Test("should keep the newer snapshot when an earlier refresh finishes last", .timeLimit(.minutes(1)))
    func shouldKeepNewerSnapshotWhenEarlierRefreshFinishesLast() async throws {
        // given
        let requests = AsyncStream<CheckedContinuation<NearbyVehicleMapFeatureState, Never>>.makeStream()
        defer { requests.continuation.finish() }
        var pending = requests.stream.makeAsyncIterator()
        var client = NearbyVehicleMapFeatureTestFactory.makeClient()
        client.refresh = { _, _ in
            await withCheckedContinuation { requests.continuation.yield($0) }
        }
        let store = NearbyVehicleMapFeatureTestFactory.makeStore(client: client)
        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }
        let earlierTask = await store.send(.locationResolutionResponse(.precise(
            latitude: 55.6761,
            longitude: 12.5683,
        ))) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }
        let earlierRequest = try #require(await pending.next())
        let newerState = NearbyVehicleMapFeatureTestFactory.loadedState(sequence: 2, vehicles: [])
        do {
            defer { earlierRequest.resume(returning: NearbyVehicleMapFeatureTestFactory.loadedSharedState()) }
            let newerTask = await store.send(.locationResolutionResponse(.precise(
                latitude: 55.6761,
                longitude: 12.5683,
            )))
            let newerRequest = try #require(await pending.next())
            let newerSharedState = try #require(newerState.sharedState)

            // when
            newerRequest.resume(returning: newerSharedState)
            await store.receive(.sharedStateLoaded(newerState)) {
                $0 = newerState
            }
            await newerTask.finish()
        }
        await earlierTask.finish()
        await store.finish()

        // then
        #expect(store.state.mapContent == newerState.mapContent)
        #expect(store.state.message == "Showing 0 vehicles around the rider.")
    }

    @MainActor
    @Test("should allow retry after Kotlin cancels the first snapshot request")
    func shouldAllowRetryAfterKotlinCancelsFirstSnapshotRequest() async {
        // given
        let service = IosInteropTestServices.shared.cancellingNearbyService()
        let store = NearbyVehicleMapFeatureTestFactory.makeStore(client: .init(service: service))
        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }
        await store.send(.locationResolutionResponse(.precise(latitude: 55.6761, longitude: 12.5683))) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }
        let readyState = NearbyVehicleMapFeatureTestFactory.readyState()

        // when
        await store.receive(.sharedStateLoaded(readyState)) {
            $0 = readyState
        }

        // then
        #expect(store.state.canRequestRefresh)
        #expect(store.state.overlay == .none)
        await store.send(.refreshTapped) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }
        await store.receive(.sharedStateLoaded(NearbyVehicleMapFeatureTestFactory.loadedState())) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadedState()
        }
    }

    @MainActor
    @Test("should retain the snapshot and allow retry after Kotlin cancels a refresh")
    func shouldRetainSnapshotAndAllowRetryAfterKotlinCancelsRefresh() async {
        // given
        let service = IosInteropTestServices.shared.cancellingNearbyService()
        let client = NearbyVehicleMapFeatureClient(service: service)
        let previousState = NearbyVehicleMapFeatureTestFactory.loadedSharedState()
        let refreshingState = client.loadingState(previousState)

        // when
        let recoveredState = await client.refresh(refreshingState, 11000)
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: recoveredState)

        // then
        #expect(recoveredState == previousState)
        #expect(state.canRequestRefresh)
        #expect(state.overlay == .none)
        #expect(state.mapContent == NearbyVehicleMapFeatureTestFactory.loadedState().mapContent)
    }

    @MainActor
    @Test("should load rider centered snapshot after precise location is resolved")
    func shouldLoadRiderCenteredSnapshotAfterPreciseLocationIsResolved() async {
        // given
        let store = NearbyVehicleMapFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }

        await store.send(.locationResolutionResponse(.precise(latitude: 55.6761, longitude: 12.5683))) {
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
        await store.send(.locationResolutionResponse(.precise(latitude: 55.6761, longitude: 12.5683))) {
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
        await store.send(.locationResolutionResponse(.precise(latitude: 55.6761, longitude: 12.5683))) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadingState()
        }
        await store.receive(.sharedStateLoaded(NearbyVehicleMapFeatureTestFactory.loadedState())) {
            $0 = NearbyVehicleMapFeatureTestFactory.loadedState()
        }

        // when
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)) {
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
        #expect(state.canInteractWithVehicles == false)
    }

    @MainActor
    @Test("should block reduced accuracy location")
    func shouldBlockReducedAccuracyLocation() async {
        // given
        let store = NearbyVehicleMapFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = NearbyVehicleMapFeatureTestFactory.initialState()
        }

        // when
        await store.send(.locationResolutionResponse(.blocked(.approximateOnly))) {
            $0 = NearbyVehicleMapFeatureTestFactory.approximateOnlyState()
        }

        // then
        #expect(store.state.message == "Precise location is required for nearby vehicle discovery.")
        #expect(store.state.overlay == .blockingFailure)
        #expect(store.state.canInteractWithVehicles == false)
    }
}

private extension Collection {
    var single: Element? {
        count == 1 ? first : nil
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

private enum NearbyVehicleMapFeatureTestFactory {
    typealias LocationBlockedReason = NearbyVehicleMapFeature.LocationBlockedReason

    @MainActor
    static func makeStore(
        client: NearbyVehicleMapFeatureClient = makeClient(),
    ) -> TestStore<NearbyVehicleMapFeature.State, NearbyVehicleMapFeature.Action> {
        TestStore(initialState: NearbyVehicleMapFeature.State()) {
            NearbyVehicleMapFeature()
        } withDependencies: {
            $0.nearbyVehicleMapFeatureClient = client
        }
    }

    static func makeClient() -> NearbyVehicleMapFeatureClient {
        NearbyVehicleMapFeatureClient(
            initialState: {
                makeSharedState(
                    riderLocationState: IosInteropTestStates.shared.riderResolving,
                    snapshotState: IosInteropTestStates.shared.snapshotInitial,
                    overlayState: IosInteropTestStates.shared.overlayNone,
                )
            },
            preciseLocationResolvedState: { currentState, latitude, longitude in
                makeSharedState(
                    riderLocationState: IosInteropTestStates.shared.riderAvailable(
                        location: RiderLocation(latitude: latitude, longitude: longitude),
                    ),
                    snapshotState: currentState.snapshotState,
                    overlayState: currentState.mapOverlayState,
                )
            },
            locationBlockedState: { _, reason in
                blockedSharedState(reason: reason)
            },
            locationTemporarilyUnavailableState: { currentState in
                makeSharedState(
                    riderLocationState: IosInteropTestStates.shared
                        .riderTemporarilyUnavailable(location: riderLocation()),
                    snapshotState: currentState.snapshotState,
                    overlayState: currentState.mapOverlayState,
                )
            },
            loadingState: { currentState in
                let snapshot = currentSnapshot(from: currentState.snapshotState)
                return makeSharedState(
                    riderLocationState: currentState.riderLocationState,
                    snapshotState: snapshot
                        .map { IosInteropTestStates.shared.snapshotRefreshing(snapshot: $0) } ??
                        IosInteropTestStates.shared.snapshotLoading,
                    overlayState: snapshot == nil ? IosInteropTestStates.shared.overlayNone : IosInteropTestStates
                        .shared.overlayRefreshing,
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
                riderLocationState: IosInteropTestStates.shared.riderResolving,
                snapshotState: IosInteropTestStates.shared.snapshotInitial,
                overlayState: IosInteropTestStates.shared.overlayNone,
            ),
        )
        return state
    }

    static func readyState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: IosInteropTestStates.shared.riderAvailable(location: riderLocation()),
                snapshotState: IosInteropTestStates.shared.snapshotInitial,
                overlayState: IosInteropTestStates.shared.overlayNone,
            ),
        )
        return state
    }

    static func loadingState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: IosInteropTestStates.shared.riderAvailable(location: riderLocation()),
                snapshotState: IosInteropTestStates.shared.snapshotLoading,
                overlayState: IosInteropTestStates.shared.overlayNone,
            ),
        )
        return state
    }

    static func refreshingState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: IosInteropTestStates.shared.riderAvailable(location: riderLocation()),
                snapshotState: IosInteropTestStates.shared.snapshotRefreshing(snapshot: snapshot()),
                overlayState: IosInteropTestStates.shared.overlayRefreshing,
            ),
        )
        return state
    }

    static func loadedState(sequence: Int64 = 1, vehicles: [NearbyVehicle]? = nil) -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: loadedSharedState(sequence: sequence, vehicles: vehicles))
        return state
    }

    static func deniedState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: deniedSharedState())
        return state
    }

    static func approximateOnlyState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(sharedState: blockedSharedState(reason: .approximateOnly))
        return state
    }

    static func temporarilyUnavailableState() -> NearbyVehicleMapFeature.State {
        var state = NearbyVehicleMapFeature.State()
        state.apply(
            sharedState: makeSharedState(
                riderLocationState: IosInteropTestStates.shared
                    .riderTemporarilyUnavailable(location: riderLocation()),
                snapshotState: IosInteropTestStates.shared.snapshotLoaded(snapshot: snapshot()),
                overlayState: IosInteropTestStates.shared.overlayNone,
            ),
        )
        return state
    }

    static func loadedSharedState(
        sequence: Int64 = 1,
        vehicles: [NearbyVehicle]? = nil,
    ) -> NearbyVehicleMapFeatureState {
        makeSharedState(
            riderLocationState: IosInteropTestStates.shared.riderAvailable(location: riderLocation()),
            snapshotState: IosInteropTestStates.shared.snapshotLoaded(snapshot: snapshot(
                sequence: sequence,
                vehicles: vehicles,
            )),
            overlayState: IosInteropTestStates.shared.overlayNone,
        )
    }

    static func deniedSharedState() -> NearbyVehicleMapFeatureState {
        blockedSharedState(reason: .accessDenied)
    }

    static func blockedSharedState(reason: LocationBlockedReason) -> NearbyVehicleMapFeatureState {
        makeSharedState(
            riderLocationState:
            reason == .accessDenied
                ? IosInteropTestStates.shared.riderDenied
                : IosInteropTestStates.shared.riderBlocked(reason: reason.sharedReason),
            snapshotState: IosInteropTestStates.shared.snapshotFailedWithout(
                reason: NearbyVehicleMapFailureReason.RiderLocationUnavailable,
            ),
            overlayState: IosInteropTestStates.shared.overlayBlocking,
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
        switch state.sealedType() {
        case .initial, .loading:
            nil
        case let .loaded(state):
            state.value.snapshot
        case let .refreshing(state):
            state.value.snapshot
        case let .failedWithSnapshot(state):
            state.value.snapshot
        case .failedWithoutSnapshot:
            nil
        }
    }

    static func snapshot(sequence: Int64 = 1, vehicles: [NearbyVehicle]? = nil) -> FleetSnapshot {
        FleetSnapshot(
            sequence: sequence,
            riderLocation: riderLocation(),
            vehicles: vehicles ?? [
                NearbyVehicle(
                    id: VehicleId(value: "mobi-ios-001"),
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
