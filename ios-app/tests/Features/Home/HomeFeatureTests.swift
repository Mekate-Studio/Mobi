@testable import app
import Foundation
import KotlinModules
import MobiIOSDependencies
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
        await store.receive(.refreshResponse(.loaded(value: 1))) {
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

    @Test("should preserve live Home client states and payloads", arguments: [0, 8])
    func shouldPreserveLiveHomeClientStatesAndPayloads(counterValue: Int) async {
        // given
        let client = HomeFeatureClient(service: HomeFeatureService(counterRepository: HomeCounterRepositoryStub()))

        // when / then
        #expect(client.initialState() == .initial)
        #expect(
            client.loadingState(counterValue)
                == .loading(previousValue: counterValue > 0 ? counterValue : nil),
        )
        let refreshed = await client.refresh(counterValue)
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
        let repository = HomeCounterRepositoryStub(failureReason: reason)
        let client = HomeFeatureClient(service: HomeFeatureService(counterRepository: repository))

        // when
        let refreshed = await client.refresh(counterValue)

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
    ) -> TestStore<HomeFeature.State, HomeFeature.Action> {
        TestStore(initialState: HomeFeature.State()) {
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

private final class HomeCounterRepositoryStub: NSObject, CounterRepository {
    let failureReason: HomeCounterLoadFailureReason?

    init(failureReason: HomeCounterLoadFailureReason? = nil) {
        self.failureReason = failureReason
    }

    func fetchNextCounterValue(
        currentCounterValue _: Int32,
        completionHandler: @escaping (KotlinInt?, (any Error)?) -> Void,
    ) {
        switch failureReason {
        case nil:
            completionHandler(KotlinInt(int: 21), nil)
        case .repositoryUnavailable?:
            completionHandler(nil, CounterRepositoryException(message: "Repository test failure").asError())
        case .unexpected?:
            completionHandler(nil, KotlinIllegalStateException(message: "Unexpected test failure").asError())
        }
    }
}
