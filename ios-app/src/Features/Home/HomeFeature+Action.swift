import MobiIOSDependencies

extension HomeFeature {
    enum Action: Equatable {
        case task
        case refreshTapped
        case refreshResponse(HomeCounterLoadable)
    }
}
