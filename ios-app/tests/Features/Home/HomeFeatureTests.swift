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
        let refreshed = await services.homeFeatureClient.refresh(0)
        #expect(refreshed == .loaded(value: 21))
    }

    @Test("should preserve Home fallback when a Swift Task is cancelled", .timeLimit(.minutes(1)))
    func shouldPreserveHomeFallbackWhenSwiftTaskIsCancelled() async {
        let client = HomeFeatureClient(service: IosInteropTestServices.shared.delayedHomeService())
        let refresh = Task { await client.refresh(8) }
        refresh.cancel()
        let result = await refresh.value
        #expect(result == .error(previousValue: 8, reason: .unexpected))
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
        let service = switch reason {
        case .repositoryUnavailable: IosInteropTestServices.shared.repositoryUnavailableHomeService()
        case .unexpected: IosInteropTestServices.shared.unexpectedFailureHomeService()
        }
        let client = HomeFeatureClient(service: service)

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
