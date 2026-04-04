import ComposableArchitecture
@preconcurrency import KotlinModules
import Testing
@testable import app

@Suite("HomeFeature")
struct HomeFeatureTests {
    @MainActor
    @Test("should load initial shared state when task is sent")
    func shouldLoadInitialSharedStateWhenTaskIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        // when / then
        await store.send(.task) {
            $0 = HomeFeatureTestFactory.expectedState(refreshCount: 0)
        }
    }

    @MainActor
    @Test("should refresh shared state when refresh action is sent after task")
    func shouldRefreshSharedStateWhenRefreshActionIsSentAfterTask() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        await store.send(.task) {
            $0 = HomeFeatureTestFactory.expectedState(refreshCount: 0)
        }

        // when / then
        await store.send(.refreshTapped) {
            $0 = HomeFeatureTestFactory.expectedState(refreshCount: 1)
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
            create: { refreshCount in
                makeSharedState(refreshCount: refreshCount)
            },
            reduce: { refreshCount in
                refreshCount + 1
            }
        )
    }

    static func makeSharedState(
        refreshCount: Int,
    ) -> HomeFeatureState {
        HomeFeatureState(
            title: "Native shell, shared feature",
            message: "Shared feature state flowing into the TestOS shell.",
            supportingText: refreshCount == 0
                ? "shared-core exposes platform context, shared-feature-home turns it into feature state, and platform shells decide how to render it."
                : "The shared reducer has already handled one refresh for the TestOS shell.",
            refreshCount: Int32(refreshCount),
            primaryActionLabel: "Refresh shared state"
        )
    }

    static func expectedState(
        refreshCount: Int,
    ) -> HomeFeature.State {
        var state = HomeFeature.State()
        state.apply(sharedState: makeSharedState(refreshCount: refreshCount))
        return state
    }
}
