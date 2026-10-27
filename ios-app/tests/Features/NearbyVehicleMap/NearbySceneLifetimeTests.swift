@testable import app
import Foundation
import MobiIOSDependencies
import MobiIOSTestDependencies
@preconcurrency import MobiNearby
import SwiftUI
import Synchronization
import Testing
import UIKit

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
    @MainActor
    @Test(
        "should cancel each Nearby trigger and recover shared snapshot state",
        .timeLimit(.minutes(1)),
        arguments: [false, true],
        [NearbyTrigger.location, .manual, .timer],
    )
    func shouldCancelNearbyTriggers(hasSnapshot: Bool, trigger: NearbyTrigger) async throws {
        // given
        let probe = NearbySceneProbe()
        defer { probe.finish() }
        var locations = probe.locations.stream.makeAsyncIterator()
        var refreshes = probe.refreshes.stream.makeAsyncIterator()
        let previous = hasSnapshot ? Factory.loadedState() : Factory.readyState()
        let store = probe.store(previous)
        var lifetime = NearbyVehicleMapLifetime()
        let task: StoreTask
        switch trigger {
        case .location:
            task = lifetime.start(in: store)
            let location = try #require(await locations.next())
            location.complete(.precise(latitude: 55.6761, longitude: 12.5683))
        case .manual:
            let started = lifetime.start(in: store)
            let location = try #require(await locations.next())
            location.complete(.temporarilyUnavailable)
            await started.finish()
            let admitted = lifetime.send(.refreshTapped, in: store)
            task = try #require(admitted)
        case .timer:
            let started = lifetime.start(in: store)
            let location = try #require(await locations.next())
            location.complete(.temporarilyUnavailable)
            await started.finish()
            let admitted = lifetime.send(.visibleRefreshDue(nowMillis: 11000), in: store)
            task = try #require(admitted)
        }
        let refresh = try #require(await refreshes.next())

        // when
        await lifetime.stop(in: store).finish()

        // then
        #expect(probe.refreshCancellations.withLock { $0 } == 1)
        #expect(snapshotMatches(store.sharedState, previous.sharedState))
        #expect(!store.canRequestRefresh)
        #expect(!store.canInteractWithVehicles)
        if hasSnapshot {
            #expect(store.mapContent == previous.mapContent)
        }
        refresh.complete(Factory.loadedSharedState(sequence: 99, vehicles: []))
        await task.finish()
        #expect(snapshotMatches(store.sharedState, previous.sharedState))

        // Return revalidates location before restoring admission; no automatic retry on fallback.
        let returned = lifetime.start(in: store)
        let location = try #require(await locations.next())
        location.complete(.temporarilyUnavailable)
        await returned.finish()
        #expect(store.canRequestRefresh)
        #expect(probe.refreshCount == 1)
        await lifetime.stop(in: store).finish()
    }

    @MainActor
    @Test("should ignore callbacks before and after a Nearby lifetime")
    func shouldIgnoreNearbyEventsOutsideLifetime() async {
        let probe = NearbySceneProbe()
        defer { probe.finish() }
        let store = probe.store(Factory.loadedState())
        var lifetime = NearbyVehicleMapLifetime()
        let previous = store.withState { $0 }
        for action in [
            NearbyVehicleMapFeature.Action.refreshTapped,
            .visibleRefreshDue(nowMillis: 11000),
            .locationResolutionResponse(.blocked(.accessDenied)),
        ] {
            let ignored = lifetime.send(action, in: store)
            #expect(ignored == nil)
            #expect(store.withState { $0 } == previous)
        }
        await lifetime.stop(in: store).finish()
        let stopped = store.withState { $0 }
        let ignored = lifetime.send(.locationResolutionResponse(.temporarilyUnavailable), in: store)
        #expect(ignored == nil)
        #expect(store.withState { $0 } == stopped)
        #expect(probe.locationCount == 0)
        #expect(probe.refreshCount == 0)
    }

    @MainActor
    @Test("should cancel Nearby even when background precedes effect registration", .timeLimit(.minutes(1)))
    func shouldCancelNearbyBeforeEffectRegistration() async {
        var client = Factory.makeClient()
        client.refresh = { _, _ in Factory.loadedSharedState(sequence: 99, vehicles: []) }
        let previous = Factory.loadedState()
        let store = Store(initialState: previous) { NearbyVehicleMapFeature() } withDependencies: {
            $0.nearbyVehicleMapFeatureClient = client
            $0.date.now = Date(timeIntervalSince1970: 11)
        }
        var lifetime = NearbyVehicleMapLifetime()
        await lifetime.start(in: store).finish()
        await store.send(.locationResolutionResponse(.temporarilyUnavailable)).finish()
        let old = lifetime.send(.refreshTapped, in: store)
        let stopped = lifetime.stop(in: store)
        #expect(!store.canRequestRefresh)
        await stopped.finish()
        await old?.finish()
        #expect(store.mapContent == previous.mapContent)
        #expect(snapshotMatches(store.sharedState, previous.sharedState))
    }

    @MainActor
    @Test("should reject a location result when background precedes its effect startup", .timeLimit(.minutes(1)))
    func shouldCancelNearbyLocationBeforeEffectStartup() async {
        await confirmation("A cancelled location cannot start a fleet request", expectedCount: 0) { requested in
            var client = Factory.makeClient()
            client.refresh = { _, _ in requested(); return Factory.loadedSharedState(sequence: 99) }
            let previous = Factory.loadedState()
            let store = Store(initialState: previous) { NearbyVehicleMapFeature() } withDependencies: {
                $0.nearbyVehicleMapFeatureClient = client
                $0.nearbyVehicleMapLocationClient = .init { .precise(latitude: 1, longitude: 2) }
                $0.date.now = Date(timeIntervalSince1970: 11)
            }
            var lifetime = NearbyVehicleMapLifetime()

            // No suspension lets the location effect register before backgrounding.
            let location = lifetime.start(in: store)
            let stopped = lifetime.stop(in: store)
            await stopped.finish()
            await location.finish()
            #expect(snapshotMatches(store.sharedState, previous.sharedState))
            #expect(store.mapContent == previous.mapContent)
            #expect(!store.canRequestRefresh)
        }
    }

    @MainActor
    @Test("should preserve Nearby task ownership across ignored busy events", .timeLimit(.minutes(1)))
    func shouldPreserveNearbyTaskAcrossBusyEvents() async throws {
        let probe = NearbySceneProbe()
        defer { probe.finish() }
        var refreshes = probe.refreshes.stream.makeAsyncIterator()
        var locations = probe.locations.stream.makeAsyncIterator()
        let store = probe.store(Factory.loadedState())
        var lifetime = NearbyVehicleMapLifetime()
        let started = lifetime.start(in: store)
        let location = try #require(await locations.next())
        location.complete(.temporarilyUnavailable)
        await started.finish()
        let admitted = lifetime.send(.refreshTapped, in: store)
        let refresh = try #require(await refreshes.next())
        await lifetime.send(.refreshTapped, in: store)?.finish()
        await lifetime.send(.visibleRefreshDue(nowMillis: 11000), in: store)?.finish()
        await lifetime.stop(in: store).finish()
        #expect(probe.refreshCount == 1)
        #expect(probe.refreshCancellations.withLock { $0 } == 1)
        refresh.complete(Factory.loadedSharedState(sequence: 99))
        await admitted?.finish()
    }

    @MainActor
    @Test(
        "should reject old Nearby location results after a new lifetime",
        .timeLimit(.minutes(1)),
        arguments: [false, true],
    )
    func shouldRejectOldNearbyLocation(newerResolved: Bool) async throws {
        let probe = NearbySceneProbe()
        defer { probe.finish() }
        var locations = probe.locations.stream.makeAsyncIterator()
        let store = probe.store(Factory.loadedState())
        var lifetime = NearbyVehicleMapLifetime()
        let oldTask = lifetime.start(in: store)
        let old = try #require(await locations.next())
        await lifetime.stop(in: store).finish()
        await Task.megaYield()
        #expect(probe.locationCancellations.withLock { $0 } == 1)
        let newTask = lifetime.start(in: store)
        let current = try #require(await locations.next())
        if newerResolved {
            current.complete(.blocked(.approximateOnly))
            await newTask.finish()
        }
        let before = store.withState { $0 }

        // A noncooperative old location provider cannot replace pending/current permission.
        old.complete(.precise(latitude: 1, longitude: 2))
        await oldTask.finish()
        #expect(store.withState { $0 } == before)
        #expect(probe.refreshCount == 0)
        if !newerResolved {
            current.complete(.blocked(.accessDenied))
            await newTask.finish()
        }
        #expect(!store.canRequestRefresh)
        await lifetime.stop(in: store).finish()
    }

    @MainActor
    @Test(
        "should reject old fleet results while a new Nearby request is pending or complete",
        .timeLimit(.minutes(1)),
        arguments: [false, true],
        [false, true],
    )
    func shouldRejectOldNearbyRefresh(newerComplete: Bool, oldFailure: Bool) async throws {
        let probe = NearbySceneProbe()
        defer { probe.finish() }
        var locations = probe.locations.stream.makeAsyncIterator()
        var refreshes = probe.refreshes.stream.makeAsyncIterator()
        let store = probe.store(Factory.loadedState())
        var lifetime = NearbyVehicleMapLifetime()
        let started = lifetime.start(in: store)
        let initialLocation = try #require(await locations.next())
        initialLocation.complete(.temporarilyUnavailable)
        await started.finish()
        let oldTaskOptional = lifetime.send(.refreshTapped, in: store)
        let oldTask = try #require(oldTaskOptional)
        let old = try #require(await refreshes.next())
        await lifetime.stop(in: store).finish()
        let newTask = lifetime.start(in: store)
        let location = try #require(await locations.next())
        location.complete(.precise(latitude: 56, longitude: 13))
        let current = try #require(await refreshes.next())
        if newerComplete {
            current.complete(Factory.loadedSharedState(sequence: 2))
            await newTask.finish()
        }
        let before = store.withState { $0 }
        old.complete(oldFailure ? Factory.deniedSharedState() : Factory.loadedSharedState(sequence: 99, vehicles: []))
        await oldTask.finish()
        #expect(store.withState { $0 } == before)
        if !newerComplete {
            current.complete(Factory.loadedSharedState(sequence: 2))
            await newTask.finish()
        }
        #expect(store.canRequestRefresh)
        #expect(snapshotMatches(store.sharedState, Factory.loadedSharedState(sequence: 2)))
        await lifetime.stop(in: store).finish()
    }

    @MainActor
    @Test(
        "should own Nearby location through inactive changes and stop on background or removal",
        .timeLimit(.minutes(1)),
    )
    func shouldOwnNearbyLocationInSwiftUI() async throws {
        let probe = NearbySceneProbe()
        defer { probe.finish() }
        var locations = probe.locations.stream.makeAsyncIterator()
        let previous = Factory.loadedState()
        let store = probe.store(previous)
        let host = try NearbySceneHost(store: store, phase: .background)
        defer { host.close() }
        await host.start()
        #expect(probe.locationCount == 0)
        await host.setPhase(.inactive)
        let first = try #require(await locations.next())
        await host.setPhase(.active)
        #expect(probe.locationCount == 1)
        #expect(probe.locationCancellations.withLock { $0 } == 0)
        await host.setPhase(.background)
        #expect(probe.locationCancellations.withLock { $0 } == 1)
        await host.setPhase(.active)
        let second = try #require(await locations.next())
        first.complete(.blocked(.accessDenied))
        await Task.megaYield()
        #expect(!store.canRequestRefresh)
        #expect(store.mapContent == previous.mapContent)
        second.complete(.temporarilyUnavailable)
        await Task.megaYield()
        #expect(store.canRequestRefresh)
        await host.setVisible(false)
        #expect(!store.canRequestRefresh)
        await host.setVisible(true)
        let third = try #require(await locations.next())
        #expect(probe.locationCount == 3)
        third.complete(.blocked(.approximateOnly))
        await Task.megaYield()
        #expect(!store.canRequestRefresh)
        #expect(store.mapContent == .waitingForRider)
        await host.stop()
    }

    @MainActor
    @Test("should cancel a hosted Nearby manual request and revalidate on return", .timeLimit(.minutes(1)))
    func shouldCancelHostedNearbyRequest() async throws {
        let probe = NearbySceneProbe()
        defer { probe.finish() }
        var locations = probe.locations.stream.makeAsyncIterator()
        var refreshes = probe.refreshes.stream.makeAsyncIterator()
        let store = probe.store(Factory.loadedState())
        let host = try NearbySceneHost(store: store)
        defer { host.close() }
        await host.start()
        let location = try #require(await locations.next())
        location.complete(.temporarilyUnavailable)
        await Task.megaYield()
        host.send?(.refreshTapped)
        let refresh = try #require(await refreshes.next())
        await host.setPhase(.inactive)
        #expect(probe.refreshCancellations.withLock { $0 } == 0)
        await host.setPhase(.background)
        #expect(probe.refreshCancellations.withLock { $0 } == 1)
        refresh.complete(Factory.loadedSharedState(sequence: 99))
        await host.setPhase(.active)
        let returned = try #require(await locations.next())
        #expect(!store.canRequestRefresh)
        returned.complete(.temporarilyUnavailable)
        await Task.megaYield()
        #expect(snapshotMatches(store.sharedState, Factory.loadedSharedState()))
        #expect(store.canRequestRefresh)
        await host.stop()
    }
}

private typealias Factory = NearbyVehicleMapFeatureTestFactory

private func snapshotMatches(
    _ current: NearbyVehicleMapFeatureState?,
    _ expected: NearbyVehicleMapFeatureState?,
) -> Bool {
    guard let current, let expected else { return false }
    return current.snapshotState == expected.snapshotState
}
