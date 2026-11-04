@testable import app
import MobiIOSDependencies
import MobiIOSTestDependencies
import SwiftUI
import Testing

extension NativeFeatureTests.HomeFeatureTests {
    @MainActor
    @Test("should ignore a retained Home callback after tab exit", .timeLimit(.minutes(1)))
    func shouldIgnoreHomeCallbackAfterTabExit() async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        let previous = HomeCounterLoadable.error(previousValue: 8, reason: .repositoryUnavailable)
        let store = probe.store(previous: previous)
        let host = try HomeTabHost(store: store)
        defer { host.close() }
        await host.start()
        let retainedRefresh = try #require(host.refresh)
        await host.selectHome(false)

        // when
        let ignored: StoreTask? = retainedRefresh()

        // then
        #expect(ignored == nil)
        #expect(store.counterLoadable == previous)
        #expect(probe.requestCount == 0)
        // Complete a baseline's incorrectly admitted client instead of hanging.
        if ignored != nil {
            var requests = probe.requests.stream.makeAsyncIterator()
            _ = await requests.next()
        }
        probe.finish()
        await ignored?.finish()
    }

    @MainActor
    @Test("should ignore Home callbacks in background and admit them on inactive return", .timeLimit(.minutes(1)))
    func shouldAdmitHomeOnlyOutsideBackground() async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let previous = HomeCounterLoadable.loaded(value: 8)
        let store = probe.store(previous: previous)
        let host = try HomeTabHost(store: store)
        defer { host.close() }
        await host.start()
        let retainedRefresh = try #require(host.refresh)

        // when
        await host.setPhase(.background)
        let ignored = retainedRefresh()

        // then
        #expect(ignored == nil)
        #expect(store.counterLoadable == previous)
        #expect(probe.requestCount == 0)
        await host.setPhase(.inactive)
        #expect(probe.requestCount == 0)
        let task = try #require(retainedRefresh())
        let pending = try #require(await requests.next())
        await host.setPhase(.active)
        #expect(probe.cancelledCount == 0)
        pending.complete(.loaded(value: 13))
        await task.finish()
        #expect(store.counterLoadable == .loaded(value: 13))
        #expect(probe.requestCount == 1)
    }

    @MainActor
    @Test(
        "should reject Home callbacks before its first eligible lifetime",
        .timeLimit(.minutes(1)),
        arguments: [false, true],
    )
    func shouldRejectHomeBeforeFirstEligibleLifetime(startsInBackground: Bool) async throws {
        // given: either an initially hidden tab or an initially backgrounded scene.
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let previous = HomeCounterLoadable.loaded(value: 8)
        let store = probe.store(previous: previous)
        let host = try HomeTabHost(
            store: store,
            selected: startsInBackground,
            phase: startsInBackground ? .background : .active,
        )
        defer { host.close() }
        await host.start()
        let retainedRefresh = try #require(host.refresh)

        // when
        let ignored = retainedRefresh()

        // then
        #expect(ignored == nil)
        #expect(store.counterLoadable == previous)
        #expect(probe.requestCount == 0)
        await host.selectHome(true)
        await host.setPhase(.active)
        #expect(probe.requestCount == 0)
        let task = try #require(retainedRefresh())
        let pending = try #require(await requests.next())
        #expect(pending.previous == previous)
        pending.complete(.loaded(value: 13))
        await task.finish()
        #expect(store.counterLoadable == .loaded(value: 13))
        #expect(probe.requestCount == 1)
    }

    @MainActor
    @Test("should reject a removed Home wrapper's callback after remounting", .timeLimit(.minutes(1)))
    func shouldRejectRemovedHomeCallback() async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let previous = HomeCounterLoadable.loaded(value: 8)
        let store = probe.store(previous: previous)
        let host = try HomeTabHost(store: store)
        defer { host.close() }
        await host.start()
        let removedRefresh = try #require(host.refresh)

        // when
        await host.setMounted(false)
        let ignored = removedRefresh()

        // then
        #expect(ignored == nil)
        #expect(store.counterLoadable == previous)
        #expect(probe.requestCount == 0)
        await host.setMounted(true)
        #expect(probe.requestCount == 0)
        let stillIgnored = removedRefresh()
        #expect(stillIgnored == nil)
        let currentRefresh = try #require(host.refresh)
        let task = try #require(currentRefresh())
        let pending = try #require(await requests.next())
        pending.complete(.loaded(value: 13))
        await task.finish()
        #expect(store.counterLoadable == .loaded(value: 13))
        #expect(probe.requestCount == 1)
    }
}
