@testable import app
import Foundation
@preconcurrency import MobiCore
@preconcurrency import MobiHome
import MobiIOSDependencies
import MobiTestSupport
import Testing
import UIKit

extension NativeFeatureTests.HomeFeatureTests {
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
    @Test(
        "should preserve existing Home state when the view task runs again",
        arguments: [
            HomeCounterLoadable.loaded(value: 8),
            .error(previousValue: 8, reason: .repositoryUnavailable),
            .loading(previousValue: 8),
        ],
    )
    func shouldPreserveExistingHomeStateWhenViewTaskRunsAgain(counterLoadable: HomeCounterLoadable) async {
        // given
        let store = HomeFeatureTestFactory.makeStore(counterLoadable: counterLoadable)

        // when
        await store.send(.task)

        // then
        #expect(store.state.counterLoadable == counterLoadable)
    }

    @MainActor
    @Test("should have refreshed shared state when repository load completes after refresh action is sent")
    func shouldHaveRefreshedSharedStateWhenRepositoryLoadCompletesAfterRefreshActionIsSent() async {
        // given
        let store = HomeFeatureTestFactory.makeStore()

        await store.send(.task)
        #expect(store.state == HomeFeatureTestFactory.expectedState(loadable: .initial))

        await store.send(.refreshTapped) {
            $0.counterLoadable = .loading(previousValue: nil)
            $0.refreshPreviousState = .initial
        }

        // when / then
        await store.receive(.refreshResponse(.loaded(value: 1))) {
            $0 = HomeFeatureTestFactory.expectedState(loadable: .loaded(value: 1))
        }
    }

    @MainActor
    @Test(
        "should ignore duplicate refresh while loading and allow refresh after completion",
        .timeLimit(.minutes(1)),
        arguments: [
            HomeCounterLoadable.loaded(value: 13),
            .error(previousValue: 8, reason: .repositoryUnavailable),
        ],
    )
    func shouldIgnoreDuplicateRefreshWhileLoadingAndAllowRefreshAfterCompletion(result: HomeCounterLoadable) async {
        await confirmation(
            "Only the first and post-completion refresh reach the client",
            expectedCount: 2,
        ) { requested in
            // given
            let completion = AsyncStream<Void>.makeStream()
            defer { completion.continuation.finish() }
            let store = TestStore(initialState: HomeFeature.State(counterLoadable: .loaded(value: 8))) {
                HomeFeature()
            } withDependencies: {
                $0.homeFeatureClient = HomeFeatureClient(
                    initialState: { .initial },
                    loadingState: { .loading(previousValue: $0) },
                    refresh: { _ in
                        requested()
                        for await _ in completion.stream {}
                        return result
                    },
                )
            }
            await store.send(.refreshTapped) {
                $0.counterLoadable = .loading(previousValue: 8)
                $0.refreshPreviousState = .loaded(value: 8)
            }

            // when
            await store.send(.refreshTapped)
            completion.continuation.finish()
            await store.receive(.refreshResponse(result)) {
                $0.counterLoadable = result
                $0.refreshPreviousState = nil
            }

            // then
            await store.send(.refreshTapped) {
                $0.counterLoadable = .loading(previousValue: result.currentValueForRefresh)
                $0.refreshPreviousState = result
            }
            await store.receive(.refreshResponse(result)) {
                $0.counterLoadable = result
                $0.refreshPreviousState = nil
            }
            await store.finish()
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
            $0.counterLoadable = .loading(previousValue: nil)
            $0.refreshPreviousState = .initial
        }

        // when / then
        await store.receive(
            .refreshResponse(.error(previousValue: nil, reason: .repositoryUnavailable)),
        ) {
            $0 = HomeFeatureTestFactory.expectedState(
                loadable: .error(
                    previousValue: nil,
                    reason: .repositoryUnavailable,
                ),
            )
        }
    }

    @MainActor
    @Test("should create Shared UI from the injected app composition")
    func shouldCreateSharedUIFromInjectedAppComposition() async {
        let services = AppServices(
            homeFeatureService: IosInteropTestServices.shared.successfulHomeService(),
            nearbyVehicleMapFeatureService: IosInteropTestServices.shared.cancellingNearbyService(),
        )
        let controller = services.makeSharedHomeViewController()
        controller.loadViewIfNeeded()
        #expect(controller.viewIfLoaded != nil)
        let refreshed = await services.homeFeatureClient.refresh(.initial)
        #expect(refreshed == .loaded(value: 21))
    }

    @Test(
        "should restore previous Home state when a Swift Task is cancelled",
        .timeLimit(.minutes(1)),
        arguments: [
            HomeCounterLoadable.initial,
            .loaded(value: 8),
            .error(previousValue: 8, reason: .repositoryUnavailable),
        ],
    )
    func shouldRestorePreviousHomeStateWhenSwiftTaskIsCancelled(previousState: HomeCounterLoadable) async {
        let client = HomeFeatureClient(service: IosInteropTestServices.shared.delayedHomeService())
        let refresh = Task { await client.refresh(previousState) }
        refresh.cancel()
        let result = await refresh.value
        #expect(result == previousState)
    }

    @MainActor
    @Test(
        "should restore previous Home state and allow retry after Kotlin cancels refresh",
        arguments: [
            HomeCounterLoadable.initial,
            .loaded(value: 8),
            .error(previousValue: 8, reason: .repositoryUnavailable),
        ],
    )
    func shouldRestorePreviousHomeStateAndAllowRetryAfterKotlinCancelsRefresh(
        previousState: HomeCounterLoadable,
    ) async {
        // given
        let client = HomeFeatureClient(service: IosInteropTestServices.shared.cancellingHomeService())
        let store = TestStore(initialState: HomeFeature.State(counterLoadable: previousState)) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = client
        }
        let loadingState = client.loadingState(previousState.currentValueForRefresh)

        // when
        await store.send(.refreshTapped) {
            $0.counterLoadable = loadingState
            $0.refreshPreviousState = previousState
        }
        await store.receive(.refreshResponse(previousState)) {
            $0.counterLoadable = previousState
            $0.refreshPreviousState = nil
        }

        // then
        #expect(!store.state.counterLoadable.isLoading)
        await store.send(.refreshTapped) {
            $0.counterLoadable = loadingState
            $0.refreshPreviousState = previousState
        }
        await store.receive(.refreshResponse(.loaded(value: 21))) {
            $0.counterLoadable = .loaded(value: 21)
            $0.refreshPreviousState = nil
        }
    }

    @Test("should preserve fallback for uncaught Kotlin failure", arguments: [0, 8])
    func shouldPreserveFallbackForUncaughtKotlinFailure(counterValue: Int) async {
        let client = HomeFeatureClient(service: IosInteropTestServices.shared.uncaughtFailureHomeService())
        let previousState = counterValue > 0 ? HomeCounterLoadable.loaded(value: counterValue) : .initial
        let refreshed = await client.refresh(previousState)
        #expect(refreshed == .error(previousValue: counterValue > 0 ? counterValue : nil, reason: .unexpected))
    }

    @Test("should preserve live Home client states and payloads", arguments: [0, 8])
    func shouldPreserveLiveHomeClientStatesAndPayloads(counterValue: Int) async {
        // given
        let client = HomeFeatureClient(service: IosInteropTestServices.shared.successfulHomeService())

        // when / then
        #expect(client.initialState() == .initial)
        #expect(
            client.loadingState(counterValue)
                == .loading(previousValue: counterValue > 0 ? counterValue : nil),
        )
        let refreshed = await client.refresh(counterValue > 0 ? .loaded(value: counterValue) : .initial)
        #expect(refreshed == .loaded(value: 21))
    }

    @Test(
        "should preserve live Home repository failures and previous values",
        arguments: [0, 8], [HomeCounterLoadFailureReason.repositoryUnavailable, .unexpected],
    )
    func shouldPreserveLiveHomeRepositoryFailuresAndPreviousValues(
        counterValue: Int,
        reason: HomeCounterLoadFailureReason,
    ) async {
        // given
        let service = switch reason {
        case .repositoryUnavailable: IosInteropTestServices.shared.repositoryUnavailableHomeService()
        case .unexpected: IosInteropTestServices.shared.unexpectedFailureHomeService()
        }
        let client = HomeFeatureClient(service: service)

        // when
        let refreshed = await client.refresh(counterValue > 0 ? .loaded(value: counterValue) : .initial)

        // then
        #expect(
            refreshed
                == .error(previousValue: counterValue > 0 ? counterValue : nil, reason: reason),
        )
    }
}

private enum HomeFeatureTestFactory {
    @MainActor
    static func makeStore(
        refreshResult: HomeCounterLoadable = .loaded(value: 1),
        counterLoadable: HomeCounterLoadable = .initial,
    ) -> TestStore<HomeFeature.State, HomeFeature.Action> {
        TestStore(initialState: expectedState(loadable: counterLoadable)) {
            HomeFeature()
        } withDependencies: {
            $0.homeFeatureClient = HomeFeatureClient(
                initialState: { .initial },
                loadingState: { counterValue in
                    .loading(previousValue: counterValue > 0 ? counterValue : nil)
                },
                refresh: { _ in
                    await Task.yield()
                    return refreshResult
                },
            )
        }
    }

    static func expectedState(loadable: HomeCounterLoadable) -> HomeFeature.State {
        HomeFeature.State(counterLoadable: loadable)
    }
}
