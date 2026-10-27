@testable import app
import Foundation
@preconcurrency import MobiCore
import MobiIOSDependencies
@preconcurrency import MobiNearby
import MobiTestSupport
import Testing

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
    @MainActor
    @Test("should age retained failures at the shared stale-window boundary", arguments: [Int64(31000), 31001], [
        NearbyVehicleMapFailureReason.RepositoryUnavailable, .Unexpected,
    ])
    func shouldAgeRetainedFailureOnReturn(
        nowMillis: Int64,
        reason: NearbyVehicleMapFailureReason,
    ) async throws {
        for (degraded, suspended) in [(false, false), (true, false), (false, true), (true, true)] {
            // given: the snapshot was loaded at 1000; failure initially remains inside the stale window.
            let service = IosInteropTestServices.shared.uncaughtFailureNearbyService()
            var client = NearbyVehicleMapFeatureClient(service: service)
            client.refresh = { state, _ in
                Issue.record("Location revalidation must not fetch a snapshot before a current location result")
                return state
            }
            let previous = degraded ? Factory.temporarilyUnavailableState() : Factory.loadedState()
            let failed = try service.failedState(
                currentState: #require(previous.sharedState), reason: reason, nowMillis: 11000,
            )
            var retained = previous
            retained.apply(sharedState: failed)
            let store = agingStore(state: retained, client: client, nowMillis: nowMillis)

            // when: a backgrounded view already has checking content before it returns.
            if suspended {
                await store.send(.suspend).finish()
            }
            await store.send(.task).finish()

            // then: aging updates shared policy before the checking presentation hides that overlay.
            let checking = try #require(store.sharedState)
            #expect(checking.snapshotState == failed.snapshotState)
            #expect(checking.riderLocationState == failed.riderLocationState)
            switch checking.mapOverlayState.sealedType() {
            case .staleIndicator:
                #expect(nowMillis == 31000)
            case .blockingFailure:
                #expect(nowMillis == 31001)
            case .none, .refreshingIndicator:
                Issue.record("A retained failure must keep a stale or blocking overlay")
            }
            #expect(!store.canRequestRefresh)
            #expect(!store.canInteractWithVehicles)
            #expect(store.mapContent == retained.mapContent)

            // when: current location is temporarily unavailable, so shared fallback uses the last point.
            await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()

            // then: fallback preserves the aged failure, its snapshot, and manual retry.
            let restored = try #require(store.sharedState)
            #expect(restored.snapshotState == failed.snapshotState)
            #expect(store.overlay == (nowMillis == 31000 ? .stale : reason.blockingPresentation))
            #expect(store.canRequestRefresh)
            #expect(store.canInteractWithVehicles == (nowMillis == 31000))
            #expect(store.mapContent == retained.mapContent)
        }
    }

    @MainActor
    @Test("should not age away a known blocked-location decision", arguments: [false, true], [
        NearbyVehicleMapFeature.LocationBlockedReason.accessDenied,
        .accessRestricted, .servicesDisabled, .approximateOnly, .temporarilyUnavailable,
    ])
    func shouldPreserveBlockedDecisionDuringFailureAging(
        hasSnapshot: Bool,
        reason: NearbyVehicleMapFeature.LocationBlockedReason,
    ) async throws {
        // given: within the stale window, unconditional shared aging would downgrade a blocking overlay.
        let client = NearbyVehicleMapFeatureClient(service: IosInteropTestServices.shared
            .uncaughtFailureNearbyService())
        let previous = hasSnapshot ? Factory.loadedState() : Factory.readyState()
        let shared = try client.locationBlockedState(#require(previous.sharedState), reason)
        var blocked = previous
        blocked.apply(sharedState: shared)
        let store = agingStore(state: blocked, client: client, nowMillis: 11000)

        // when
        await store.send(.task).finish()

        // then
        #expect(store.sharedState == shared)
        #expect(store.overlay.blocksMap)
        #expect(store.mapContent == .waitingForRider)
        #expect(!store.canRequestRefresh)
        #expect(!store.canInteractWithVehicles)
    }

    @MainActor
    @Test("should leave healthy and snapshot-absent states under existing shared policy", arguments: [
        NearbyVehicleMapFailureReason.RepositoryUnavailable, .Unexpected,
    ])
    func shouldKeepHealthyAndSnapshotAbsentStatesUnchanged(reason: NearbyVehicleMapFailureReason) async throws {
        // given
        let service = IosInteropTestServices.shared.uncaughtFailureNearbyService()
        let client = NearbyVehicleMapFeatureClient(service: service)
        let loaded = Factory.loadedState()
        var failedWithoutSnapshot = Factory.readyState()
        try failedWithoutSnapshot.apply(sharedState: service.failedState(
            currentState: #require(failedWithoutSnapshot.sharedState), reason: reason, nowMillis: 11000,
        ))
        for previous in [loaded, failedWithoutSnapshot] {
            let shared = try #require(previous.sharedState)
            let store = agingStore(state: previous, client: client, nowMillis: 31001)

            // when
            await store.send(.task).finish()
            await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()

            // then
            let restored = try #require(store.sharedState)
            #expect(restored.snapshotState == shared.snapshotState)
            #expect(restored.mapOverlayState == shared.mapOverlayState)
            #expect(store.canRequestRefresh)
        }
    }

    @MainActor
    @Test("should allow manual retry after retained failure expires", arguments: [
        NearbyVehicleMapFailureReason.RepositoryUnavailable, .Unexpected,
    ])
    func shouldRetryExpiredRetainedFailure(reason: NearbyVehicleMapFailureReason) async throws {
        try await confirmation("One manual retry uses the current injected date", expectedCount: 1) { requested in
            // given
            let service = IosInteropTestServices.shared.uncaughtFailureNearbyService()
            var client = NearbyVehicleMapFeatureClient(service: service)
            client.refresh = { _, nowMillis in
                #expect(nowMillis == 31001)
                requested()
                return Factory.loadedSharedState(sequence: 2, vehicles: [])
            }
            var previous = Factory.loadedState()
            try previous.apply(sharedState: service.failedState(
                currentState: #require(previous.sharedState), reason: reason, nowMillis: 11000,
            ))
            let store = agingStore(state: previous, client: client, nowMillis: 31001)
            await store.send(.task).finish()
            await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()
            #expect(store.overlay.blocksMap)
            #expect(store.canRequestRefresh)

            // when
            await store.send(.refreshTapped).finish()

            // then
            let refreshed = try #require(store.sharedState)
            #expect(refreshed.snapshotState == Factory.loadedSharedState(sequence: 2, vehicles: []).snapshotState)
            #expect(store.overlay == .none)
            #expect(store.canInteractWithVehicles)
            #expect(store.canRequestRefresh)
        }
    }
}

private typealias Factory = NearbyVehicleMapFeatureTestFactory

@MainActor
private func agingStore(
    state: NearbyVehicleMapFeature.State,
    client: NearbyVehicleMapFeatureClient,
    nowMillis: Int64,
) -> StoreOf<NearbyVehicleMapFeature> {
    Store(initialState: state) {
        NearbyVehicleMapFeature()
    } withDependencies: {
        $0.nearbyVehicleMapFeatureClient = client
        $0.date.now = Date(timeIntervalSince1970: Double(nowMillis) / 1000)
    }
}

private extension NearbyVehicleMapFailureReason {
    var blockingPresentation: NearbyVehicleMapOverlay {
        switch self {
        case .RepositoryUnavailable:
            .blocking(
                headline: "Map unavailable",
                message:
                "The fleet repository could not load nearby vehicles. Try refreshing again.",
            )
        case .Unexpected:
            .blocking(
                headline: "Map unavailable",
                message:
                "Something went wrong while loading nearby vehicles. Try refreshing again.",
            )
        case .RiderLocationUnavailable:
            .blockingFailure
        }
    }
}
