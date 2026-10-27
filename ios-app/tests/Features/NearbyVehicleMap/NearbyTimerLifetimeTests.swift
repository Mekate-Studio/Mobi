@testable import app
import Foundation
import MobiIOSDependencies
import MobiIOSTestDependencies
@preconcurrency import MobiNearby
import SwiftUI
import Testing
import UIKit

extension NativeFeatureTests.NearbyVehicleMapFeatureTests {
    @MainActor
    @Test("should preserve Nearby timer cadence through inactive and loading recomposition", .timeLimit(.minutes(1)))
    func shouldPreserveNearbyTimerCadenceThroughInactiveAndRecomposition() async throws {
        // given
        let host = try NearbyTimerHost()
        defer { host.close() }
        await host.start()
        await host.clock.advance(by: .seconds(5))

        // when
        await host.setPhase(.inactive)
        await host.clock.advance(by: .seconds(5))

        // then: each tick also re-renders the host, as a loading state would.
        #expect(host.ticks == 1)
        await host.clock.advance(by: .seconds(10))
        #expect(host.ticks == 2)
        await host.setPhase(.active)
        await host.clock.advance(by: .seconds(10))
        #expect(host.ticks == 3)
        await host.stop()
    }

    @MainActor
    @Test("should stop Nearby timer ticks in background and restart a full delay", .timeLimit(.minutes(1)))
    func shouldStopNearbyTimerInBackgroundAndRestartFullDelay() async throws {
        // given
        let host = try NearbyTimerHost()
        defer { host.close() }
        await host.start()
        for expectedTicks in 1 ... 3 {
            await host.clock.advance(by: .seconds(5))

            // when
            await host.setPhase(.background)
            await host.clock.advance(by: .seconds(30))

            // then
            #expect(host.ticks == expectedTicks - 1)
            await host.setPhase(.active)
            #expect(host.ticks == expectedTicks - 1)
            await host.clock.advance(by: .milliseconds(9999))
            #expect(host.ticks == expectedTicks - 1)
            await host.clock.advance(by: .milliseconds(1))
            #expect(host.ticks == expectedTicks)
        }
        await host.stop()
    }

    @MainActor
    @Test("should wait while initially backgrounded without replaying missed ticks", .timeLimit(.minutes(1)))
    func shouldWaitWhileNearbyTimerIsInitiallyBackgrounded() async throws {
        // given
        let host = try NearbyTimerHost(phase: .background)
        defer { host.close() }
        await host.start()

        // when
        await host.clock.advance(by: .seconds(30))

        // then
        #expect(host.ticks == 0)
        await host.setPhase(.inactive)
        await host.clock.advance(by: .milliseconds(9999))
        #expect(host.ticks == 0)
        await host.setPhase(.active)
        await host.clock.advance(by: .milliseconds(1))
        #expect(host.ticks == 1)
        await host.stop()
    }

    @MainActor
    @Test("should cancel Nearby timer on view removal and start one timer on reentry", .timeLimit(.minutes(1)))
    func shouldCancelNearbyTimerOnRemovalAndStartOneOnReentry() async throws {
        // given
        let host = try NearbyTimerHost()
        defer { host.close() }
        await host.start()
        await host.clock.advance(by: .seconds(10))
        #expect(host.ticks == 1)

        // when
        await host.setVisible(false)
        await host.clock.advance(by: .seconds(30))

        // then
        #expect(host.ticks == 1)
        await host.setVisible(true)
        await host.clock.advance(by: .seconds(10))
        #expect(host.ticks == 2)
        await host.stop()
    }

    @MainActor
    @Test("should pause scheduling without cancelling an admitted Nearby refresh", .timeLimit(.minutes(1)))
    func shouldPauseNearbySchedulingWithoutCancellingAdmittedRefresh() async throws {
        // given
        let completions = AsyncStream<CheckedContinuation<NearbyVehicleMapFeatureState, Never>>.makeStream()
        defer { completions.continuation.finish() }
        var pending = completions.stream.makeAsyncIterator()
        var client = NearbyVehicleMapFeatureTestFactory.makeClient()
        client.shouldRefresh = { _, _ in true }
        client.refresh = { _, _ in
            await withCheckedContinuation { completions.continuation.yield($0) }
        }
        let ready = NearbyVehicleMapFeatureTestFactory.loadedState()
        let store = Store(initialState: ready) { NearbyVehicleMapFeature() } withDependencies: {
            $0.nearbyVehicleMapFeatureClient = client
        }
        var refresh: StoreTask?
        let host = try NearbyTimerHost {
            refresh = store.send(.visibleRefreshDue(nowMillis: 11000))
        }
        defer { host.close() }
        await host.start()
        await host.clock.advance(by: .seconds(10))
        let first = try #require(await pending.next())
        let admitted = try #require(refresh)
        #expect(!store.canRequestRefresh)
        #expect(store.mapContent == ready.mapContent)

        // when
        await host.setPhase(.background)
        await host.clock.advance(by: .seconds(30))

        // then
        #expect(host.ticks == 1)
        #expect(!admitted.isCancelled)
        first.resume(returning: NearbyVehicleMapFeatureTestFactory.loadedSharedState(sequence: 2))
        await admitted.finish()
        #expect(store.mapContent == NearbyVehicleMapFeatureTestFactory.loadedState(sequence: 2).mapContent)
        #expect(store.canRequestRefresh)
        await host.setPhase(.active)
        await host.clock.advance(by: .milliseconds(9999))
        #expect(host.ticks == 1)
        await host.clock.advance(by: .milliseconds(1))
        let second = try #require(await pending.next())
        second.resume(returning: NearbyVehicleMapFeatureTestFactory.loadedSharedState(sequence: 3))
        await refresh?.finish()
        #expect(host.ticks == 2)
        await host.stop()
    }
}

@MainActor
private final class NearbyTimerHost {
    let clock = TestClock<Duration>()
    private(set) var ticks = 0
    private var phase: ScenePhase
    private var visible = true
    private let onTick: @MainActor () -> Void
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private lazy var controller = UIHostingController(rootView: content)

    init(phase: ScenePhase = .active, onTick: @escaping @MainActor () -> Void = {}) throws {
        self.phase = phase
        self.onTick = onTick
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        previousKeyWindow = scene.windows.first { $0.isKeyWindow }
    }

    private var content: NearbyTimerTestView {
        NearbyTimerTestView(phase: phase, visible: visible, ticks: ticks, clock: clock) { [weak self] in
            guard let self else { return }
            ticks += 1
            onTick()
            render()
        }
    }

    func start() async {
        window.rootViewController = controller
        window.makeKeyAndVisible()
        render()
        await Task.megaYield()
    }

    func setPhase(_ phase: ScenePhase) async {
        self.phase = phase
        render()
        await Task.megaYield()
    }

    func setVisible(_ visible: Bool) async {
        self.visible = visible
        render()
        await Task.megaYield()
    }

    private func render() {
        controller.rootView = content
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func close() {
        visible = false
        render()
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKeyAndVisible()
    }

    func stop() async {
        close()
        await Task.megaYield()
    }
}

private struct NearbyTimerTestView: View {
    let phase: ScenePhase
    let visible: Bool
    let ticks: Int
    let clock: TestClock<Duration>
    let onTick: @MainActor () -> Void

    var body: some View {
        Group {
            if visible {
                Text("Ticks: \(ticks)")
                    .modifier(NearbyRefreshTimer(clock: clock, onTick: onTick))
            }
        }
        .environment(\.scenePhase, phase)
    }
}
