import MobiIOSDependencies

extension NearbyVehicleMapFeature {
    enum LocationPermissionResult: Equatable {
        case granted
        case denied
        case temporarilyUnavailable
    }

    enum Action: Equatable {
        case task
        case locationPermissionResponse(LocationPermissionResult)
        case refreshTapped
        case visibleRefreshDue(nowMillis: Int64)
        case sharedStateLoaded(State)
    }
}
