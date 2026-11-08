@testable import app
import Foundation
import MobiIOSDependencies
import MobiIOSTestDependencies
import MobiNearby
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
        await host.advance(by: .seconds(5))

        // when
        await host.setPhase(.inactive)
        await host.advance(by: .seconds(5))

        // then: each tick also re-renders the host, as a loading state would.
        #expect(host.ticks == 1)
        await host.advance(by: .seconds(10))
        #expect(host.ticks == 2)
        await host.setPhase(.active)
        await host.advance(by: .seconds(10))
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
            await host.advance(by: .seconds(5))

            // when
            await host.setPhase(.background)
            await host.advance(by: .seconds(30))

            // then
            #expect(host.ticks == expectedTicks - 1)
            await host.setPhase(.active)
            #expect(host.ticks == expectedTicks - 1)
            await host.advance(by: .milliseconds(9999))
            #expect(host.ticks == expectedTicks - 1)
            await host.advance(by: .milliseconds(1))
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
        await host.advance(by: .seconds(30))

        // then
        #expect(host.ticks == 0)
        await host.setPhase(.inactive)
        await host.advance(by: .milliseconds(9999))
        #expect(host.ticks == 0)
        await host.setPhase(.active)
        await host.advance(by: .milliseconds(1))
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
        await host.advance(by: .seconds(10))
        #expect(host.ticks == 1)

        // when
        await host.setVisible(false)
        await host.advance(by: .seconds(30))

        // then
        #expect(host.ticks == 1)
        await host.setVisible(true)
        await host.advance(by: .seconds(10))
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
        await host.advance(by: .seconds(10))
        let first = try #require(await pending.next())
        let admitted = try #require(refresh)
        #expect(!store.canRequestRefresh)
        #expect(store.mapContent == ready.mapContent)

        // when
        await host.setPhase(.background)
        await host.advance(by: .seconds(30))

        // then
        #expect(host.ticks == 1)
        #expect(!admitted.isCancelled)
        first.resume(returning: NearbyVehicleMapFeatureTestFactory.loadedSharedState(sequence: 2))
        await admitted.finish()
        #expect(store.mapContent == NearbyVehicleMapFeatureTestFactory.loadedState(sequence: 2).mapContent)
        #expect(store.canRequestRefresh)
        await host.setPhase(.active)
        await host.advance(by: .milliseconds(9999))
        #expect(host.ticks == 1)
        await host.advance(by: .milliseconds(1))
        let second = try #require(await pending.next())
        second.resume(returning: NearbyVehicleMapFeatureTestFactory.loadedSharedState(sequence: 3))
        await refresh?.finish()
        #expect(host.ticks == 2)
        await host.stop()
    }
}

@MainActor
private final class NearbyTimerHost {
    private let clock = TestClock<Duration>()
    private(set) var ticks = 0
    private var phase: ScenePhase
    private var visible = true
    private let onTick: @MainActor () -> Void
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private let rendered = AsyncStream<NearbyTimerInput>.makeStream()
    private lazy var controller = UIHostingController(rootView: content)

    init(phase: ScenePhase = .active, onTick: @escaping @MainActor () -> Void = {}) throws {
        self.phase = phase
        self.onTick = onTick
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        previousKeyWindow = scene.windows.first { $0.isKeyWindow }
    }

    private var content: NearbyTimerTestView {
        NearbyTimerTestView(
            input: NearbyTimerInput(phase: phase, visible: visible, ticks: ticks),
            clock: clock,
            onTick: { [weak self] in
                guard let self else { return }
                ticks += 1
                onTick()
                updateRoot()
            },
            onRender: { [rendered] in rendered.continuation.yield($0) },
        )
    }

    func start() async {
        window.rootViewController = controller
        window.makeKeyAndVisible()
        await render()
    }

    func advance(by duration: Duration) async {
        // IOS-13: scope TestClock's background yields to the serialized test executor.
        await withMainSerialExecutor {
            await clock.advance(by: duration)
        }
    }

    func setPhase(_ phase: ScenePhase) async {
        guard self.phase != phase else { return }
        self.phase = phase
        await render()
    }

    func setVisible(_ visible: Bool) async {
        guard self.visible != visible else { return }
        self.visible = visible
        await render()
    }

    private func render() async {
        let expected = NearbyTimerInput(phase: phase, visible: visible, ticks: ticks)
        updateRoot()
        for await input in rendered.stream where input == expected {
            return
        }
        Issue.record("Hosted Nearby timer did not consume its scene/visibility input")
    }

    private func updateRoot() {
        controller.rootView = content
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func close() {
        visible = false
        updateRoot()
        rendered.continuation.finish()
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKeyAndVisible()
    }

    func stop() async {
        await setVisible(false)
        close()
    }
}

private struct NearbyTimerInput: Equatable {
    let phase: ScenePhase
    let visible: Bool
    let ticks: Int
}

private struct NearbyTimerTestView: View {
    let input: NearbyTimerInput
    let clock: TestClock<Duration>
    let onTick: @MainActor () -> Void
    let onRender: (NearbyTimerInput) -> Void

    var body: some View {
        Group {
            if input.visible {
                Text("Ticks: \(input.ticks)")
                    .modifier(NearbyRefreshTimer(clock: clock, onTick: onTick))
            }
        }
        .environment(\.scenePhase, input.phase)
        .onChange(of: input, initial: true) { _, input in onRender(input) }
    }
}
