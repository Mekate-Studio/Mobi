import MobiIOSDependencies

extension NearbyVehicleMapFeature {
    enum LocationBlockedReason: Equatable, Sendable {
        case accessDenied
        case accessRestricted
        case servicesDisabled
        case approximateOnly
        case temporarilyUnavailable
    }

    enum LocationResolutionResult: Equatable, Sendable {
        case precise(
            latitude: Double,
            longitude: Double,
        )
        case blocked(LocationBlockedReason)
        case temporarilyUnavailable
    }

    enum Action: Equatable {
        case task
        case locationResolutionResponse(LocationResolutionResult)
        case refreshTapped
        case visibleRefreshDue(nowMillis: Int64)
        case sharedStateLoaded(State)
    }
}
