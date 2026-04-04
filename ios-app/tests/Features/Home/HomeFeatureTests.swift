import ComposableArchitecture
import Foundation
@preconcurrency import KotlinModules
import Testing
@testable import app

@Suite("HomeFeature")
struct HomeFeatureTests {
    @MainActor
    @Test("should have initial shared state when task is sent")
    func shouldHaveInitialSharedStateWhenTaskIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        // when / then
        await store.send(.task) {
            $0 = HomeFeatureTestFactory.expectedState(loadable: .initial)
        }
    }

    @MainActor
    @Test("should have refreshed shared state when repository load completes after refresh action is sent")
    func shouldHaveRefreshedSharedStateWhenRepositoryLoadCompletesAfterRefreshActionIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = HomeFeatureTestFactory.expectedState(loadable: .initial)
        }

        await store.send(.refreshTapped) {
            $0 = HomeFeatureTestFactory.expectedState(
                loadable: .loading(previousValue: nil)
            )
        }

        // when / then
        await store.receive(.sharedStateLoaded(HomeFeatureTestFactory.expectedState(loadable: .loaded(value: 1)))) {
            $0 = HomeFeatureTestFactory.expectedState(loadable: .loaded(value: 1))
        }
    }

    @MainActor
    @Test("should have error shared state when repository load fails after refresh action is sent")
    func shouldHaveErrorSharedStateWhenRepositoryLoadFailsAfterRefreshActionIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore(
            refreshResult: .error(
                previousValue: nil,
                message: "The fake repository failed to load the next fibonacci counter value."
            )
        )

        await store.send(.task) {
            $0 = HomeFeatureTestFactory.expectedState(loadable: .initial)
        }

        await store.send(.refreshTapped) {
            $0 = HomeFeatureTestFactory.expectedState(
                loadable: .loading(previousValue: nil)
            )
        }

        // when / then
        await store.receive(
            .sharedStateLoaded(
                HomeFeatureTestFactory.expectedState(
                    loadable: .error(
                        previousValue: nil,
                        message: "The fake repository failed to load the next fibonacci counter value."
                    )
                )
            )
        ) {
            $0 = HomeFeatureTestFactory.expectedState(
                loadable: .error(
                    previousValue: nil,
                    message: "The fake repository failed to load the next fibonacci counter value."
                )
            )
        }
    }
}

private enum HomeFeatureTestFactory {
    static func makeStore(
        refreshResult: HomeCounterLoadable = .loaded(value: 1)
    ) -> TestStore<HomeFeature.State, HomeFeature.Action> {
        TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = makeHomeFeatureClient(refreshResult: refreshResult)
        }
    }

    static func makeHomeFeatureClient(
        refreshResult: HomeCounterLoadable
    ) -> HomeFeatureClient {
        HomeFeatureClient(
            initialState: {
                makeSharedState(loadable: .initial)
            },
            loadingState: { counterValue in
                makeSharedState(
                    loadable: .loading(previousValue: counterValue > 0 ? counterValue : nil)
                )
            },
            refresh: { counterValue in
                await Task.yield()
                let resolvedLoadable: HomeCounterLoadable
                switch refreshResult {
                case .loaded:
                    resolvedLoadable = .loaded(value: nextCounterValue(after: counterValue))
                case .error(_, let message):
                    resolvedLoadable = .error(
                        previousValue: counterValue > 0 ? counterValue : nil,
                        message: message
                    )
                default:
                    resolvedLoadable = refreshResult
                }
                return makeSharedState(loadable: resolvedLoadable)
            }
        )
    }

    static func makeSharedState(
        loadable: HomeCounterLoadable
    ) -> HomeFeatureState {
        HomeFeatureState(
            title: "Native shell, shared feature",
            message: "Shared feature state flowing into the TestOS shell.",
            supportingText: supportingText(loadable: loadable),
            primaryActionLabel: "Load next counter value",
            counterLoadable: makeSharedLoadable(loadable: loadable)
        )
    }

    static func expectedState(
        loadable: HomeCounterLoadable
    ) -> HomeFeature.State {
        var state = HomeFeature.State()
        state.apply(
            sharedState: makeSharedState(loadable: loadable)
        )
        return state
    }

    static func supportingText(
        loadable: HomeCounterLoadable
    ) -> String {
        switch loadable {
        case .initial:
            return "shared-core exposes platform context, shared-feature-home fetches counter values from a fake repository, and platform shells decide how to render them."
        case .loading:
            return "Loading the next fibonacci counter value from the fake repository for the TestOS shell."
        case let .loaded(value):
            return "The fake repository returned fibonacci counter value \(value) for the TestOS shell."
        case let .error(previousValue, message):
            if let previousValue {
                return "\(message) Showing last known counter value \(previousValue) in the TestOS shell."
            }
            return "\(message) No fibonacci counter value was loaded yet for the TestOS shell."
        }
    }

    static func makeSharedLoadable(
        loadable: HomeCounterLoadable
    ) -> CounterLoadable {
        switch loadable {
        case .initial:
            return CounterLoadableInitial.shared
        case let .loading(previousValue):
            return CounterLoadableLoading(
                previousValue: previousValue.map { KotlinInt(int: Int32($0)) }
            )
        case let .loaded(value):
            return CounterLoadableLoaded(value: Int32(value))
        case let .error(previousValue, message):
            return CounterLoadableError(
                previousValue: previousValue.map { KotlinInt(int: Int32($0)) },
                message: message
            )
        }
    }

    static func nextCounterValue(after counterValue: Int) -> Int {
        if counterValue < 1 { return 1 }

        var previous = 0
        var current = 1

        while current <= counterValue {
            let next = previous + current
            previous = current
            current = next
        }

        return current
    }
}
