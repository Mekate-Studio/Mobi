import MobiIOSDependencies
import SwiftUI

extension HomeFeature {
    enum Action: Equatable {
        case scenePhaseChanged(ScenePhase)
        case task
        case refreshTapped
        case refreshResponse(HomeCounterLoadable)
    }
}
