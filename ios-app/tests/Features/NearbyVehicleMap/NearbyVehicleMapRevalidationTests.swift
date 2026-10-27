@testable import app
import Foundation
@preconcurrency import MobiCore
import MobiIOSDependencies
@preconcurrency import MobiNearby
import MobiTestSupport
import Testing

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
    @MainActor
    @Test("should gate retained Nearby content while current location is checked", arguments: [false, true])
    func shouldGateRetainedContentWhileCheckingLocation(hasSnapshot: Bool) async {
        // given
        let previous = hasSnapshot ? Factory.loadedState() : Factory.readyState()
        let store = runtimeStore(state: previous)

        // when
        await store.send(.task).finish()

        // then
        #expect(!store.canRequestRefresh)
        #expect(!store.canInteractWithVehicles)
        #expect(store.sharedState == previous.sharedState)
        if hasSnapshot {
            #expect(store.mapContent == previous.mapContent)
            #expect(store.overlay == .banner(headline: "Checking location", message: checkingMessage))
            #expect(store.message == checkingMessage)
        } else {
            #expect(store.mapContent == .waitingForRider)
        }
    }

    @MainActor
    @Test("should reject manual and timer refresh while rechecking location")
    func shouldRejectRefreshWhileCheckingLocation() async {
        await confirmation("No work is admitted during location checking", expectedCount: 0) { requested in
            // given
            var client = Factory.makeClient()
            client.loadingState = { state in requested(); return state }
            client.refresh = { state, _ in requested(); return state }
            client.shouldRefresh = { _, _ in requested(); return true }
            let store = runtimeStore(state: Factory.loadedState(), client: client)

            // when
            await store.send(.task).finish()
            await store.send(.refreshTapped).finish()
            await store.send(.visibleRefreshDue(nowMillis: 31001)).finish()

            // then
            #expect(!store.canRequestRefresh)
        }
    }

    @MainActor
    @Test("should preserve the last position when revalidation temporarily fails", arguments: [false, true])
    func shouldPreservePositionWhenRevalidationTemporarilyFails(hasSnapshot: Bool) async throws {
        // given: exercise the real shared fallback with and without a fleet snapshot.
        let client = NearbyVehicleMapFeatureClient(service: IosInteropTestServices.shared
            .uncaughtFailureNearbyService())
        let previous = hasSnapshot ? Factory.temporarilyUnavailableState() : Factory.readyState()
        let retained = try #require(previous.sharedState)
        let expected = client.locationTemporarilyUnavailableState(retained)
        let store = runtimeStore(state: previous, client: client)
        await store.send(.task).finish()
        #expect(!store.canRequestRefresh)

        // when
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()

        // then
        #expect(store.sharedState == expected)
        #expect(store.mapContent == previous.mapContent)
        #expect(store.canRequestRefresh)
        #expect(store.canInteractWithVehicles)
    }

    @MainActor
    @Test("should keep blocked decisions until a current precise result", arguments: [false, true], [
        NearbyVehicleMapFeature.LocationBlockedReason.accessDenied,
        .accessRestricted, .servicesDisabled, .approximateOnly, .temporarilyUnavailable,
    ])
    func shouldKeepBlockedDecisionDuringRevalidation(
        hasSnapshot: Bool,
        reason: NearbyVehicleMapFeature.LocationBlockedReason,
    ) async throws {
        // given
        let client = NearbyVehicleMapFeatureClient(service: IosInteropTestServices.shared
            .uncaughtFailureNearbyService())
        let previous = hasSnapshot ? Factory.loadedState() : Factory.readyState()
        var blocked = previous
        try blocked.apply(sharedState: client.locationBlockedState(#require(previous.sharedState), reason))
        let store = runtimeStore(state: blocked, client: client)

        // when
        await store.send(.task).finish()
        await store.send(.refreshTapped).finish()
        await store.send(.visibleRefreshDue(nowMillis: 31001)).finish()

        // then
        #expect(store.sharedState == blocked.sharedState)
        #expect(store.mapContent == .waitingForRider)
        #expect(store.overlay.blocksMap)
        #expect(!store.canRequestRefresh)
        #expect(!store.canInteractWithVehicles)
    }

    @MainActor
    @Test("should finish location checking and refresh from the current precise result")
    func shouldRefreshFromCurrentPreciseResult() async throws {
        // given
        let requests = AsyncStream<NearbyVehicleMapFeatureState>.makeStream()
        defer { requests.continuation.finish() }
        var pending = requests.stream.makeAsyncIterator()
        var client = Factory.makeClient()
        client.refresh = { state, _ in
            requests.continuation.yield(state)
            return Factory.loadedSharedState(sequence: 2)
        }
        let store = runtimeStore(state: Factory.loadedState(), client: client)
        await store.send(.task).finish()
        #expect(!store.canInteractWithVehicles)

        // when
        await store.send(.locationResolutionResponse(.precise(latitude: 56, longitude: 13))).finish()

        // then
        let request = try #require(await pending.next())
        #expect(request.riderLocationState == IosInteropTestStates.shared.riderAvailable(
            location: RiderLocation(latitude: 56, longitude: 13),
        ))
        let resolved = try #require(store.sharedState)
        #expect(resolved.riderLocationState == request.riderLocationState)
        #expect(resolved.snapshotState == Factory.loadedSharedState(sequence: 2).snapshotState)
        guard case let .riderCentered(scene) = store.mapContent else {
            Issue.record("The current precise result must center the map")
            return
        }
        #expect(scene.riderMarker.coordinate == NearbyVehicleMapCoordinate(latitude: 56, longitude: 13))
        #expect(store.canRequestRefresh)
        #expect(store.canInteractWithVehicles)
    }

    @MainActor
    @Test("should preserve shared failure meaning through a location check", arguments: [false, true], [
        NearbyVehicleMapFailureReason.RepositoryUnavailable, .Unexpected,
    ])
    func shouldPreserveFailureThroughLocationCheck(
        hasSnapshot: Bool,
        reason: NearbyVehicleMapFailureReason,
    ) async throws {
        // given
        let service = IosInteropTestServices.shared.uncaughtFailureNearbyService()
        let client = NearbyVehicleMapFeatureClient(service: service)
        let previous = hasSnapshot ? Factory.loadedState() : Factory.readyState()
        let failed = try service.failedState(
            currentState: #require(previous.sharedState), reason: reason, nowMillis: 11000,
        )
        var previousFailure = previous
        previousFailure.apply(sharedState: failed)
        let store = runtimeStore(state: previousFailure, client: client)

        // when
        await store.send(.task).finish()
        #expect(!store.canRequestRefresh)
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()

        // then: this fixture's date remains inside the shared stale window.
        let restored = try #require(store.sharedState)
        #expect(restored.snapshotState == failed.snapshotState)
        #expect(store.overlay == previousFailure.overlay)
        #expect(store.mapContent == previousFailure.mapContent)
        #expect(store.canRequestRefresh)
    }

    @MainActor
    @Test("should recover retry after rechecking a pending snapshot", arguments: [false, true])
    func shouldRecoverRetryAfterRecheckingPendingSnapshot(hasSnapshot: Bool) async throws {
        // given
        let client = NearbyVehicleMapFeatureClient(service: IosInteropTestServices.shared
            .uncaughtFailureNearbyService())
        let previous = hasSnapshot ? Factory.loadedState() : Factory.readyState()
        let retained = try #require(previous.sharedState)
        var pending = previous
        pending.apply(sharedState: client.loadingState(retained))
        let store = runtimeStore(state: pending, client: client)

        // when
        await store.send(.task).finish()
        #expect(!store.canRequestRefresh)
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()

        // then
        let restored = try #require(store.sharedState)
        #expect(restored.snapshotState == retained.snapshotState)
        #expect(store.canRequestRefresh)
        #expect(store.canInteractWithVehicles)
    }

    @MainActor
    @Test("should ignore a refresh result while location is still being checked")
    func shouldIgnoreRefreshResultWhileCheckingLocation() async {
        // given
        let previous = Factory.loadedState()
        let store = runtimeStore(state: previous)
        await store.send(.task).finish()

        // when
        await store.send(.sharedStateLoaded(Factory.loadedState(sequence: 99))).finish()

        // then
        #expect(store.mapContent == previous.mapContent)
        #expect(!store.canRequestRefresh)
        #expect(!store.canInteractWithVehicles)
    }

    @MainActor
    @Test("should reject a Nearby result when revalidation precedes effect startup", .timeLimit(.minutes(1)))
    func shouldRejectNearbyResultWhenRevalidationPrecedesEffectStartup() async {
        // given
        var client = Factory.makeClient()
        client.refresh = { _, _ in Factory.loadedSharedState(sequence: 99, vehicles: []) }
        let previous = Factory.loadedState()
        let store = runtimeStore(state: previous, client: client)

        // when: the old effect has not had a turn to register its cancellation ID.
        var lifetime = NearbyVehicleMapLifetime()
        await lifetime.start(in: store).finish()
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()
        let refresh = lifetime.send(.refreshTapped, in: store)
        let revalidation = lifetime.start(in: store)
        let resolved = store.send(.locationResolutionResponse(.temporarilyUnavailable))
        await revalidation.finish()
        await resolved.finish()
        await refresh?.finish()

        // then
        #expect(store.mapContent == previous.mapContent)
        #expect(store.canRequestRefresh)
    }

    @MainActor
    @Test("should reject a pre-revalidation response without losing retry", .timeLimit(.minutes(1)))
    func shouldRejectResponseFromBeforeRevalidation() async throws {
        // given
        let requests = AsyncStream<CheckedContinuation<NearbyVehicleMapFeatureState, Never>>.makeStream()
        defer { requests.continuation.finish() }
        var pending = requests.stream.makeAsyncIterator()
        var client = Factory.makeClient()
        client.refresh = { _, _ in
            await withCheckedContinuation { requests.continuation.yield($0) }
        }
        let previous = Factory.loadedState()
        let store = runtimeStore(state: previous, client: client)
        var lifetime = NearbyVehicleMapLifetime()
        await lifetime.start(in: store).finish()
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()
        let oldTaskOptional = lifetime.send(.refreshTapped, in: store)
        let oldTask = try #require(oldTaskOptional)
        let oldRequest = try #require(await pending.next())

        // when: the old provider ignores cancellation and completes after the new location check.
        await lifetime.start(in: store).finish()
        #expect(!store.canInteractWithVehicles)
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()
        oldRequest.resume(returning: Factory.loadedSharedState(sequence: 99, vehicles: []))
        await oldTask.finish()

        // then
        let retained = try #require(previous.sharedState)
        let current = try #require(store.sharedState)
        #expect(current.snapshotState == retained.snapshotState)
        #expect(store.mapContent == previous.mapContent)
        #expect(store.canRequestRefresh)
        #expect(store.canInteractWithVehicles)
    }
}

private typealias Factory = NearbyVehicleMapFeatureTestFactory
private let checkingMessage = "Keeping the last snapshot visible while precise rider location is checked."

@MainActor
private func runtimeStore(
    state: NearbyVehicleMapFeature.State,
    client: NearbyVehicleMapFeatureClient = Factory.makeClient(),
) -> StoreOf<NearbyVehicleMapFeature> {
    Store(initialState: state) {
        NearbyVehicleMapFeature()
    } withDependencies: {
        $0.nearbyVehicleMapFeatureClient = client
        $0.date.now = Date(timeIntervalSince1970: 11)
    }
}
