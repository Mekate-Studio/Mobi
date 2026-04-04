import ComposableArchitecture

extension HomeFeature {
    enum Action: Equatable {
        case task
        case refreshTapped
        case sharedStateLoaded(State)
    }
}
