@testable import app
import MobiIOSDependencies
import MobiIOSTestDependencies
import Observation
import SwiftUI
import Testing
import UIKit

extension NativeFeatureTests.HomeFeatureTests {
    @MainActor
    @Test(
        "should cancel Home refresh when its tab is deselected",
        .timeLimit(.minutes(1)),
        arguments: HomeBackgroundFixture.readyStates,
    )
    func shouldCancelHomeWhenTabIsDeselected(previous: HomeCounterLoadable) async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let store = probe.store(previous: previous)
        let host = try HomeTabHost(store: store)
        defer { host.close() }
        await host.start()
        let refresh = try #require(host.refresh)
        let task = try #require(refresh())
        let pending = try #require(await requests.next())

        // when
        await host.selectHome(false)

        // then
        #expect(probe.cancelledCount == 1)
        #expect(store.counterLoadable == previous)
        pending.complete(.loaded(value: 99))
        await task.finish()
        #expect(store.counterLoadable == previous)
        await host.selectHome(true)
        #expect(store.counterLoadable == previous)
        #expect(probe.requestCount == 1)
    }

    @MainActor
    @Test(
        "should retry Home after tab return without an old result replacing newer work",
        .timeLimit(.minutes(1)),
        arguments: [false, true], [false, true],
    )
    func shouldRetryHomeAfterTabReturn(newerComplete: Bool, oldFailure: Bool) async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let previous = HomeCounterLoadable.error(previousValue: 8, reason: .repositoryUnavailable)
        let store = probe.store(previous: previous)
        let host = try HomeTabHost(store: store)
        defer { host.close() }
        await host.start()
        let refresh = try #require(host.refresh)
        let oldTask = try #require(refresh())
        let older = try #require(await requests.next())
        await host.selectHome(false)
        await host.selectHome(true)
        #expect(store.counterLoadable == previous)
        #expect(probe.requestCount == 1)
        guard !store.counterLoadable.isLoading else {
            older.complete(.loaded(value: 99))
            await oldTask.finish()
            Issue.record("Tab exit must restore ready state before retry")
            return
        }

        // when
        let retryRefresh = try #require(host.refresh)
        let retry = try #require(retryRefresh())
        let newer = try #require(await requests.next())
        #expect(newer.previous == previous)
        if newerComplete {
            newer.complete(.loaded(value: 13))
            await retry.finish()
        }
        older.complete(oldFailure ? .error(previousValue: 8, reason: .unexpected) : .loaded(value: 99))
        await oldTask.finish()

        // then
        #expect(store.counterLoadable == (newerComplete ? .loaded(value: 13) : .loading(previousValue: 8)))
        if !newerComplete {
            newer.complete(.loaded(value: 13))
            await retry.finish()
        }
        #expect(store.counterLoadable == .loaded(value: 13))
        #expect(probe.requestCount == 2)
        #expect(probe.cancelledCount == 1)
    }

    @MainActor
    @Test(
        "should preserve Home work through inactive scenes and recover once across hidden transitions",
        .timeLimit(.minutes(1)),
    )
    func shouldPreserveHomeAcrossTabAndSceneTransitions() async throws {
        // given
        let probe = HomeBackgroundFixture()
        defer { probe.finish() }
        var requests = probe.requests.stream.makeAsyncIterator()
        let previous = HomeCounterLoadable.loaded(value: 8)
        let store = probe.store(previous: previous)
        let host = try HomeTabHost(store: store)
        defer { host.close() }
        await host.start()
        let refresh = try #require(host.refresh)
        let task = try #require(refresh())
        let pending = try #require(await requests.next())

        // when
        await host.setPhase(.inactive)
        await host.setPhase(.active)
        #expect(probe.cancelledCount == 0)
        #expect(store.counterLoadable == .loading(previousValue: 8))
        await host.selectHome(false)
        await host.setPhase(.background)
        await host.selectHome(false)
        await host.selectHome(true)
        await host.setPhase(.active)

        // then
        #expect(probe.cancelledCount == 1)
        #expect(probe.requestCount == 1)
        #expect(store.counterLoadable == previous)
        #expect(store.refreshPreviousState == nil)
        pending.complete(.loaded(value: 99))
        await task.finish()
        #expect(store.counterLoadable == previous)
    }
}

@MainActor
final class HomeTabHost {
    let store: StoreOf<HomeFeature>
    var refresh: (() -> StoreTask?)?
    private let model: HomeTabModel
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private let rendered = AsyncStream<HomeTabInput>.makeStream()
    private lazy var controller = UIHostingController(rootView: content)

    init(store: StoreOf<HomeFeature>, selected: Bool = true, phase: ScenePhase = .active) throws {
        self.store = store
        model = HomeTabModel(input: HomeTabInput(selected: selected, phase: phase))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        previousKeyWindow = scene.windows.first { $0.isKeyWindow }
    }

    private var content: HomeTabTestView {
        HomeTabTestView(
            store: store,
            model: model,
            onRefresh: { [weak self] in self?.refresh = $0 },
            onRender: { [rendered] in rendered.continuation.yield($0) },
        )
    }

    func start() async {
        window.rootViewController = controller
        window.makeKeyAndVisible()
        await render()
    }

    func selectHome(_ selected: Bool) async {
        guard model.input.selected != selected else { return }
        model.input.selected = selected
        await render()
    }

    func setPhase(_ phase: ScenePhase) async {
        guard model.input.phase != phase else { return }
        model.input.phase = phase
        await render()
    }

    func setMounted(_ mounted: Bool) async {
        guard model.input.mounted != mounted else { return }
        model.input.mounted = mounted
        await render()
    }

    private func render() async {
        let expected = model.input
        for await value in rendered.stream where value == expected {
            await Task.megaYield()
            return
        }
        Issue.record("Hosted Home tabs did not consume their input")
    }

    func close() {
        rendered.continuation.finish()
        refresh = nil
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKeyAndVisible()
    }
}

@MainActor
@Observable
private final class HomeTabModel {
    var input: HomeTabInput

    init(input: HomeTabInput) {
        self.input = input
    }
}

private struct HomeTabInput: Equatable {
    var selected = true
    var phase = ScenePhase.active
    var mounted = true
}

private struct HomeTabTestView: View {
    let store: StoreOf<HomeFeature>
    @Bindable var model: HomeTabModel
    let onRefresh: (@escaping () -> StoreTask?) -> Void
    let onRender: (HomeTabInput) -> Void

    var body: some View {
        Group {
            if model.input.mounted {
                HomeRefreshLifecycle(store: store, isHomeSelected: model.input.selected) { refresh in
                    TabView(selection: $model.input.selected) {
                        Text(store.counterLoadable.supportingText)
                            .tabItem { Text("Home") }
                            .tag(true)
                        Text("Other")
                            .tabItem { Text("Other") }
                            .tag(false)
                    }
                    .onAppear { onRefresh(refresh) }
                }
            }
        }
        .environment(\.scenePhase, model.input.phase)
        .onChange(of: model.input, initial: true) { _, value in onRender(value) }
    }
}
