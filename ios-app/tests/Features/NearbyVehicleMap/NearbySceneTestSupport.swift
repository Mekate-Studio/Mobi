@testable import app
import Foundation
import MobiIOSDependencies
import MobiIOSTestDependencies
@preconcurrency import MobiNearby
import SwiftUI
import Synchronization
import Testing
import UIKit

enum NearbyTrigger: Sendable { case location, manual, timer }
private typealias Factory = NearbyVehicleMapFeatureTestFactory
private typealias LocationResult = NearbyVehicleMapFeature.LocationResolutionResult

final class NearbySceneProbe: Sendable {
    let locations = AsyncStream<NearbyPending<NearbyVehicleMapFeature.LocationResolutionResult?>>.makeStream()
    let refreshes = AsyncStream<NearbyPending<NearbyVehicleMapFeatureState>>.makeStream()
    let locationCancellations = Mutex(0)
    let refreshCancellations = Mutex(0)
    private let pendingLocations = Mutex<[NearbyPending<LocationResult?>]>([])
    private let pendingRefreshes = Mutex<[NearbyPending<NearbyVehicleMapFeatureState>]>([])
    var locationCount: Int {
        pendingLocations.withLock { $0.count }
    }

    var refreshCount: Int {
        pendingRefreshes.withLock { $0.count }
    }

    @MainActor
    func store(_ state: NearbyVehicleMapFeature.State) -> StoreOf<NearbyVehicleMapFeature> {
        var client = Factory.makeClient()
        client.shouldRefresh = { _, _ in true }
        client.refresh = { _, _ in
            await withTaskCancellationHandler {
                await withCheckedContinuation { completion in
                    let request = NearbyPending(completion)
                    self.pendingRefreshes.withLock { $0.append(request) }
                    self.refreshes.continuation.yield(request)
                }
            } onCancel: { self.refreshCancellations.withLock { $0 += 1 } }
        }
        return Store(initialState: state) { NearbyVehicleMapFeature() } withDependencies: {
            $0.nearbyVehicleMapFeatureClient = client
            $0.nearbyVehicleMapLocationClient = .init {
                await withTaskCancellationHandler {
                    await withCheckedContinuation { completion in
                        let request = NearbyPending(completion)
                        self.pendingLocations.withLock { $0.append(request) }
                        self.locations.continuation.yield(request)
                    }
                } onCancel: { self.locationCancellations.withLock { $0 += 1 } }
            }
            $0.date.now = Date(timeIntervalSince1970: 11)
        }
    }

    func finish() {
        pendingLocations.withLock { $0 }.forEach { $0.complete(nil) }
        pendingRefreshes.withLock { $0 }.forEach { $0.complete(Factory.loadedSharedState()) }
        locations.continuation.finish()
        refreshes.continuation.finish()
    }
}

final class NearbyPending<Value: Sendable>: Sendable {
    private let completion: Mutex<CheckedContinuation<Value, Never>?>
    init(_ completion: CheckedContinuation<Value, Never>) {
        self.completion = Mutex(completion)
    }

    func complete(_ value: Value) {
        let pending = completion.withLock { completion in
            defer { completion = nil }
            return completion
        }
        pending?.resume(returning: value)
    }
}

@MainActor
final class NearbySceneHost {
    let store: StoreOf<NearbyVehicleMapFeature>
    var send: ((NearbyVehicleMapFeature.Action) -> Void)?
    private var phase: ScenePhase
    private var visible = true
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private let rendered = AsyncStream<NearbySceneInput>.makeStream()
    private lazy var controller = UIHostingController(rootView: content)

    init(store: StoreOf<NearbyVehicleMapFeature>, phase: ScenePhase = .active) throws {
        self.store = store
        self.phase = phase
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        previousKeyWindow = scene.windows.first { $0.isKeyWindow }
    }

    private var content: NearbySceneTestView {
        NearbySceneTestView(
            store: store,
            input: NearbySceneInput(phase: phase, visible: visible),
            onSend: { [weak self] send in self?.send = send },
            onRender: { [rendered] input in rendered.continuation.yield(input) },
        )
    }

    func start() async {
        window.rootViewController = controller
        window.makeKeyAndVisible()
        await render()
    }

    func setPhase(_ phase: ScenePhase) async {
        self.phase = phase
        await render()
    }

    func setVisible(_ visible: Bool) async {
        self.visible = visible
        await render()
    }

    private func render() async {
        let expected = NearbySceneInput(phase: phase, visible: visible)
        updateRoot()
        for await input in rendered.stream where input == expected {
            return
        }
        Issue.record("Hosted Nearby view did not consume its scene/visibility input")
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
        send = nil
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKeyAndVisible()
    }

    func stop() async {
        close(); await Task.megaYield()
    }
}

private struct NearbySceneTestView: View {
    let store: StoreOf<NearbyVehicleMapFeature>
    let input: NearbySceneInput
    let onSend: (@escaping (NearbyVehicleMapFeature.Action) -> Void) -> Void
    let onRender: (NearbySceneInput) -> Void

    var body: some View {
        Group {
            if input.visible {
                NearbyVehicleMapLifecycle(store: store) { send in
                    Text(store.message).onAppear { onSend(send) }
                }
            }
        }
        .environment(\.scenePhase, input.phase)
        .onChange(of: input, initial: true) { _, input in onRender(input) }
    }
}

private struct NearbySceneInput: Equatable {
    let phase: ScenePhase
    let visible: Bool
}
