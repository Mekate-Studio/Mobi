@testable import app
import Foundation
import MobiIOSDependencies
import SwiftUI
import Synchronization
import Testing

extension NativeFeatureTests.HomeFeatureTests {
    @MainActor
    @Test(
        "should cancel Home on background and restore its exact previous state",
        .timeLimit(.minutes(1)),
        arguments: HomeBackgroundFixture.readyStates,
    )
    func shouldCancelHomeOnBackgroundAndRestorePreviousState(previous: HomeCounterLoadable) async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let store = probe.store(previous: previous)
        var lifetime = HomeRefreshLifetime()
        let refresh = lifetime.refresh(in: store)
        let pending = try #require(await requests.next())
        #expect(store.counterLoadable.isLoading)

        // when
        await lifetime.scenePhaseChanged(.background, in: store).finish()

        // then
        #expect(probe.cancelledCount == 1)
        #expect(store.counterLoadable == previous)
        pending.complete(.loaded(value: 99))
        await refresh.finish()
        #expect(store.counterLoadable == previous)
    }

    @MainActor
    @Test(
        "should reject a Home result when background arrives before the refresh effect starts",
        .timeLimit(.minutes(1)),
    )
    func shouldRejectHomeResultWhenBackgroundArrivesBeforeEffectStarts() async {
        // given
        let store = Store(initialState: HomeFeature.State(counterLoadable: .loaded(value: 8))) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = HomeFeatureClient(
                initialState: { .initial },
                loadingState: { .loading(previousValue: $0) },
                refresh: { _ in .loaded(value: 99) },
            )
        }

        var lifetime = HomeRefreshLifetime()

        // when: no suspension gives the effect time to register before backgrounding.
        let refresh = lifetime.refresh(in: store)
        let background = lifetime.scenePhaseChanged(.background, in: store)
        #expect(store.counterLoadable == .loaded(value: 8))
        await background.finish()
        await refresh.finish()

        // then
        #expect(store.counterLoadable == .loaded(value: 8))
    }

    @MainActor
    @Test("should keep the owned Home task when duplicate refresh is ignored", .timeLimit(.minutes(1)))
    func shouldKeepOwnedHomeTaskWhenDuplicateRefreshIsIgnored() async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let store = probe.store(previous: .loaded(value: 8))
        var lifetime = HomeRefreshLifetime()
        let refresh = lifetime.refresh(in: store)
        let pending = try #require(await requests.next())

        // when
        await lifetime.refresh(in: store).finish()
        await lifetime.scenePhaseChanged(.background, in: store).finish()

        // then
        #expect(probe.requestCount == 1)
        #expect(probe.cancelledCount == 1)
        #expect(store.counterLoadable == .loaded(value: 8))
        pending.complete(.loaded(value: 99))
        await refresh.finish()
        #expect(store.counterLoadable == .loaded(value: 8))
    }

    @MainActor
    @Test("should let Home finish across inactive and active scene changes", .timeLimit(.minutes(1)))
    func shouldLetHomeFinishAcrossInactiveAndActiveSceneChanges() async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let store = probe.store(previous: .loaded(value: 8))
        var lifetime = HomeRefreshLifetime()
        let refresh = lifetime.refresh(in: store)
        let pending = try #require(await requests.next())

        // when
        await lifetime.scenePhaseChanged(.inactive, in: store).finish()
        await lifetime.scenePhaseChanged(.active, in: store).finish()

        // then
        #expect(probe.cancelledCount == 0)
        #expect(store.counterLoadable == .loading(previousValue: 8))
        pending.complete(.loaded(value: 13))
        await refresh.finish()
        #expect(store.counterLoadable == .loaded(value: 13))
        #expect(probe.requestCount == 1)
    }

    @MainActor
    @Test(
        "should retain ready Home states across repeated scene changes without fetching",
        arguments: HomeBackgroundFixture.readyStates,
    )
    func shouldRetainReadyHomeAcrossSceneChanges(previous: HomeCounterLoadable) async {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        let store = probe.store(previous: previous)
        var lifetime = HomeRefreshLifetime()

        // when
        for phase in [ScenePhase.inactive, .background, .active, .background, .background, .active] {
            await lifetime.scenePhaseChanged(phase, in: store).finish()
            #expect(store.counterLoadable == previous)
        }

        // then
        #expect(probe.requestCount == 0)
        #expect(probe.cancelledCount == 0)
    }

    @MainActor
    @Test(
        "should allow retry after background without an old result replacing newer work",
        .timeLimit(.minutes(1)),
        arguments: [false, true],
        [false, true],
    )
    func shouldRetryHomeAfterBackgroundWithoutOldResults(newerComplete: Bool, oldFailure: Bool) async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let previous = HomeCounterLoadable.error(previousValue: 8, reason: .repositoryUnavailable)
        let store = probe.store(previous: previous)
        var lifetime = HomeRefreshLifetime()
        let oldRefresh = lifetime.refresh(in: store)
        let older = try #require(await requests.next())
        await lifetime.scenePhaseChanged(.background, in: store).finish()
        await lifetime.scenePhaseChanged(.active, in: store).finish()
        #expect(probe.requestCount == 1)
        #expect(store.counterLoadable == previous)

        // when
        // A failed recovery cannot admit retry; complete the fake rather than hang.
        guard !store.counterLoadable.isLoading else {
            older.complete(.loaded(value: 99))
            await oldRefresh.finish()
            Issue.record("Background must restore ready state before retry")
            return
        }
        let retry = lifetime.refresh(in: store)
        let newer = try #require(await requests.next())
        #expect(newer.previous == previous)
        if newerComplete {
            newer.complete(.loaded(value: 13))
            await retry.finish()
        }
        older.complete(oldFailure ? .error(previousValue: 8, reason: .unexpected) : .loaded(value: 99))
        await oldRefresh.finish()

        // then
        #expect(store.counterLoadable == (newerComplete ? .loaded(value: 13) : .loading(previousValue: 8)))
        if !newerComplete {
            newer.complete(.loaded(value: 13))
            await retry.finish()
        }
        #expect(store.counterLoadable == .loaded(value: 13))
        #expect(probe.requestCount == 2)
    }
}

private final class HomeBackgroundFixture: Sendable {
    static let readyStates: [HomeCounterLoadable] = [
        .initial, .loaded(value: 0), .loaded(value: 8),
        .error(previousValue: nil, reason: .repositoryUnavailable),
        .error(previousValue: 8, reason: .repositoryUnavailable),
        .error(previousValue: nil, reason: .unexpected),
        .error(previousValue: 8, reason: .unexpected),
    ]
    let requests = AsyncStream<PendingHomeRefresh>.makeStream()
    private let pending = Mutex<[PendingHomeRefresh]>([])
    private let cancellations = Mutex(0)
    var requestCount: Int {
        pending.withLock { $0.count }
    }

    var cancelledCount: Int {
        cancellations.withLock { $0 }
    }

    @MainActor
    func store(previous: HomeCounterLoadable) -> StoreOf<HomeFeature> {
        Store(initialState: HomeFeature.State(counterLoadable: previous)) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = HomeFeatureClient(
                initialState: { .initial },
                loadingState: { .loading(previousValue: $0 > 0 ? $0 : nil) },
                refresh: { previous in
                    await withTaskCancellationHandler {
                        await withCheckedContinuation { completion in
                            let request = PendingHomeRefresh(previous: previous, completion: completion)
                            self.pending.withLock { $0.append(request) }
                            self.requests.continuation.yield(request)
                        }
                    } onCancel: {
                        self.cancellations.withLock { $0 += 1 }
                    }
                },
            )
        }
    }

    func finish() {
        pending.withLock { $0 }.forEach { $0.complete(.initial) }
        requests.continuation.finish()
    }
}

private final class PendingHomeRefresh: Sendable {
    let previous: HomeCounterLoadable
    private let completion: Mutex<CheckedContinuation<HomeCounterLoadable, Never>?>

    init(previous: HomeCounterLoadable, completion: CheckedContinuation<HomeCounterLoadable, Never>) {
        self.previous = previous
        self.completion = Mutex(completion)
    }

    func complete(_ value: HomeCounterLoadable) {
        let continuation = completion.withLock { completion in
            defer { completion = nil }
            return completion
        }
        continuation?.resume(returning: value)
    }
}
