@testable import app
import MobiIOSDependencies
import Foundation
@preconcurrency import KotlinModules
import Testing

@Suite("HomeFeature")
struct HomeFeatureTests {
    @MainActor
    @Test("should have initial shared state when task is sent")
    func shouldHaveInitialSharedStateWhenTaskIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        // when
        await store.send(.task)

        // then
        #expect(store.state == HomeFeatureTestFactory.expectedState(loadable: .initial))
    }

    @MainActor
    @Test("should have refreshed shared state when repository load completes after refresh action is sent")
    func shouldHaveRefreshedSharedStateWhenRepositoryLoadCompletesAfterRefreshActionIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        await store.send(.task)
        #expect(store.state == HomeFeatureTestFactory.expectedState(loadable: .initial))

        await store.send(.refreshTapped) {
            $0 = HomeFeatureTestFactory.expectedState(
                loadable: .loading(previousValue: nil),
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
                reason: .repositoryUnavailable,
            ),
        )

        await store.send(.task)
        #expect(store.state == HomeFeatureTestFactory.expectedState(loadable: .initial))

        await store.send(.refreshTapped) {
            $0 = HomeFeatureTestFactory.expectedState(
                loadable: .loading(previousValue: nil),
            )
        }

        // when / then
        await store.receive(
            .sharedStateLoaded(
                HomeFeatureTestFactory.expectedState(
                    loadable: .error(
                        previousValue: nil,
                        reason: .repositoryUnavailable,
                    ),
                ),
            ),
        ) {
            $0 = HomeFeatureTestFactory.expectedState(
                loadable: .error(
                    previousValue: nil,
                    reason: .repositoryUnavailable,
                ),
            )
        }
    }
}

private enum HomeFeatureTestFactory {
    @MainActor
    static func makeStore(
        refreshResult: HomeCounterLoadable = .loaded(value: 1),
    ) -> TestStore<HomeFeature.State, HomeFeature.Action> {
        TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = makeHomeFeatureClient(refreshResult: refreshResult)
        }
    }

    static func makeHomeFeatureClient(
        refreshResult: HomeCounterLoadable,
    ) -> HomeFeatureClient {
        HomeFeatureClient(
            initialState: {
                makeSharedState(loadable: .initial)
            },
            loadingState: { counterValue in
                makeSharedState(
                    loadable: .loading(previousValue: counterValue > 0 ? counterValue : nil),
                )
            },
            refresh: { counterValue in
                await Task.yield()
                let resolvedLoadable: HomeCounterLoadable = switch refreshResult {
                case .loaded:
                    .loaded(value: nextCounterValue(after: counterValue))
                case let .error(_, reason):
                    .error(
                        previousValue: counterValue > 0 ? counterValue : nil,
                        reason: reason,
                    )
                default:
                    refreshResult
                }
                return makeSharedState(loadable: resolvedLoadable)
            },
        )
    }

    static func makeSharedState(
        loadable: HomeCounterLoadable,
    ) -> HomeFeatureState {
        HomeFeatureState(
            counterLoadable: makeSharedLoadable(loadable: loadable),
        )
    }

    static func expectedState(
        loadable: HomeCounterLoadable,
    ) -> HomeFeature.State {
        var state = HomeFeature.State()
        state.apply(
            sharedState: makeSharedState(loadable: loadable),
        )
        return state
    }

    static func makeSharedLoadable(
        loadable: HomeCounterLoadable,
    ) -> CounterLoadable {
        switch loadable {
        case .initial:
            CounterLoadableInitial.shared
        case let .loading(previousValue):
            CounterLoadableLoading(
                previousValue: previousValue.map { KotlinInt(int: Int32($0)) },
            )
        case let .loaded(value):
            CounterLoadableLoaded(value: Int32(value))
        case let .error(previousValue, reason):
            CounterLoadableError(
                previousValue: previousValue.map { KotlinInt(int: Int32($0)) },
                reason: makeSharedFailureReason(reason: reason),
            )
        }
    }

    static func makeSharedFailureReason(
        reason: HomeCounterLoadFailureReason,
    ) -> CounterLoadFailureReason {
        switch reason {
        case .repositoryUnavailable:
            CounterLoadFailureReasonRepositoryUnavailable.shared
        case .unexpected:
            CounterLoadFailureReasonUnexpected.shared
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
