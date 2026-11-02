@testable import app
import MobiIOSDependencies
import MobiIOSTestDependencies
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
        let task = refresh()
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
        let oldTask = refresh()
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
        let retry = retryRefresh()
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
        let task = refresh()
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
private final class HomeTabHost {
    let store: StoreOf<HomeFeature>
    var refresh: (() -> StoreTask)?
    private var input = HomeTabInput()
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private let rendered = AsyncStream<HomeTabInput>.makeStream()
    private lazy var controller = UIHostingController(rootView: content)

    init(store: StoreOf<HomeFeature>) throws {
        self.store = store
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        previousKeyWindow = scene.windows.first { $0.isKeyWindow }
    }

    private var content: HomeTabTestView {
        HomeTabTestView(
            store: store,
            input: input,
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
        guard input.selected != selected else { return }
        input.selected = selected
        await render()
    }

    func setPhase(_ phase: ScenePhase) async {
        guard input.phase != phase else { return }
        input.phase = phase
        await render()
    }

    private func render() async {
        controller.rootView = content
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        for await value in rendered.stream where value == input {
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

private struct HomeTabInput: Equatable {
    var selected = true
    var phase = ScenePhase.active
}

private struct HomeTabTestView: View {
    let store: StoreOf<HomeFeature>
    let input: HomeTabInput
    let onRefresh: (@escaping () -> StoreTask) -> Void
    let onRender: (HomeTabInput) -> Void

    var body: some View {
        HomeRefreshLifecycle(store: store, isHomeSelected: input.selected) { refresh in
            TabView(selection: .constant(input.selected)) {
                Text(store.counterLoadable.supportingText)
                    .onAppear { onRefresh(refresh) }
                    .tabItem { Text("Home") }
                    .tag(true)
                Text("Other")
                    .tabItem { Text("Other") }
                    .tag(false)
            }
        }
        .environment(\.scenePhase, input.phase)
        .onChange(of: input, initial: true) { _, value in onRender(value) }
    }
}
