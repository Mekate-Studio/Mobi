import ComposableArchitecture
@preconcurrency import KotlinModules
import XCTest
@testable import app

@MainActor
final class HomeFeatureTests: XCTestCase {
    func testTaskLoadsInitialSharedState() async {
        let store = makeStore()

        await store.send(.task) {
            $0.title = "Native shell, shared feature"
            $0.message = "Shared feature state flowing into the TestOS shell."
            $0.supportingText = "shared-core exposes platform context, shared-feature-home turns it into feature state, and platform shells decide how to render it."
            $0.refreshCount = 0
            $0.primaryActionLabel = "Refresh shared state"
        }
    }

    func testRefreshTappedAdvancesSharedState() async {
        let store = makeStore()

        await store.send(.task) {
            $0.title = "Native shell, shared feature"
            $0.message = "Shared feature state flowing into the TestOS shell."
            $0.supportingText = "shared-core exposes platform context, shared-feature-home turns it into feature state, and platform shells decide how to render it."
            $0.refreshCount = 0
            $0.primaryActionLabel = "Refresh shared state"
        }

        await store.send(.refreshTapped) {
            $0.title = "Native shell, shared feature"
            $0.message = "Shared feature state flowing into the TestOS shell."
            $0.supportingText = "The shared reducer has already handled one refresh for the TestOS shell."
            $0.refreshCount = 1
            $0.primaryActionLabel = "Refresh shared state"
        }
    }

    private func makeStore() -> TestStore<HomeFeature.State, HomeFeature.Action> {
        TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = HomeFeatureClient(
                create: { refreshCount in
                    HomeFeatureState(
                        title: "Native shell, shared feature",
                        message: "Shared feature state flowing into the TestOS shell.",
                        supportingText: refreshCount == 0
                            ? "shared-core exposes platform context, shared-feature-home turns it into feature state, and platform shells decide how to render it."
                            : "The shared reducer has already handled one refresh for the TestOS shell.",
                        refreshCount: Int32(refreshCount),
                        primaryActionLabel: "Refresh shared state"
                    )
                },
                reduce: { refreshCount in
                    refreshCount + 1
                }
            )
        }
    }
}
