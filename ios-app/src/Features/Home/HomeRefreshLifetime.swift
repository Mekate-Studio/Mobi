import MobiIOSDependencies
import SwiftUI

@MainActor
struct HomeRefreshLifetime {
    private var refreshTask: StoreTask?

    @discardableResult
    mutating func refresh(in store: StoreOf<HomeFeature>) -> StoreTask {
        let task = store.send(.refreshTapped)
        if !task.isCancelled {
            refreshTask = task
        }
        return task
    }

    @discardableResult
    mutating func scenePhaseChanged(_ phase: ScenePhase, in store: StoreOf<HomeFeature>) -> StoreTask {
        if phase == .background {
            refreshTask?.cancel()
            refreshTask = nil
        }
        return store.send(.scenePhaseChanged(phase))
    }
}
