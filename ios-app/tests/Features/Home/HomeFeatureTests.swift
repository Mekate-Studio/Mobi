import ComposableArchitecture
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
            $0 = HomeFeatureTestFactory.expectedState(counterValue: 0)
        }
    }

    @MainActor
    @Test("should have loading shared state when refresh action is sent after task")
    func shouldHaveLoadingSharedStateWhenRefreshActionIsSentAfterTask() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = HomeFeatureTestFactory.expectedState(counterValue: 0)
        }

        // when / then
        await store.send(.refreshTapped) {
            $0 = HomeFeatureTestFactory.expectedState(
                counterValue: 0,
                isLoading: true
            )
        }
        await store.skipReceivedActions()
    }

    @MainActor
    @Test("should have refreshed shared state when repository load completes after refresh action is sent")
    func shouldHaveRefreshedSharedStateWhenRepositoryLoadCompletesAfterRefreshActionIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = HomeFeatureTestFactory.expectedState(counterValue: 0)
        }

        await store.send(.refreshTapped) {
            $0 = HomeFeatureTestFactory.expectedState(
                counterValue: 0,
                isLoading: true
            )
        }

        // when / then
        await store.receive(.sharedStateLoaded(HomeFeatureTestFactory.expectedState(counterValue: 1))) {
            $0 = HomeFeatureTestFactory.expectedState(counterValue: 1)
        }
    }
}

private enum HomeFeatureTestFactory {
    static func makeStore() -> TestStore<HomeFeature.State, HomeFeature.Action> {
        TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = makeHomeFeatureClient()
        }
    }

    static func makeHomeFeatureClient() -> HomeFeatureClient {
        HomeFeatureClient(
            initialState: {
                makeSharedState(counterValue: 0)
            },
            loadingState: { counterValue in
                makeSharedState(
                    counterValue: counterValue,
                    isLoading: true
                )
            },
            refresh: { counterValue in
                await Task.yield()
                return makeSharedState(counterValue: nextCounterValue(after: counterValue))
            }
        )
    }

    static func makeSharedState(
        counterValue: Int,
        isLoading: Bool = false
    ) -> HomeFeatureState {
        HomeFeatureState(
            title: "Native shell, shared feature",
            message: "Shared feature state flowing into the TestOS shell.",
            supportingText: supportingText(
                counterValue: counterValue,
                isLoading: isLoading
            ),
            counterValue: Int32(counterValue),
            primaryActionLabel: "Load next counter value",
            isLoading: isLoading
        )
    }

    static func expectedState(
        counterValue: Int,
        isLoading: Bool = false
    ) -> HomeFeature.State {
        var state = HomeFeature.State()
        state.apply(
            sharedState: makeSharedState(
                counterValue: counterValue,
                isLoading: isLoading
            )
        )
        return state
    }

    static func supportingText(
        counterValue: Int,
        isLoading: Bool
    ) -> String {
        if isLoading {
            return "Loading the next fibonacci counter value from the fake repository for the TestOS shell."
        }

        if counterValue == 0 {
            return "shared-core exposes platform context, shared-feature-home fetches counter values from a fake repository, and platform shells decide how to render them."
        }

        return "The fake repository returned fibonacci counter value \(counterValue) for the TestOS shell."
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
