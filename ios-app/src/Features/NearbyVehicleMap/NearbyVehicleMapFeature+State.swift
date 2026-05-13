import ComposableArchitecture
@preconcurrency import KotlinModules

extension NearbyVehicleMapFeature {
    @ObservableState
    struct State: Equatable {
        var sharedState: NearbyVehicleMapFeatureState?

        static func == (
            lhs: State,
            rhs: State,
        ) -> Bool {
            lhs.message == rhs.message &&
                lhs.mapContent == rhs.mapContent &&
                lhs.overlay == rhs.overlay &&
                lhs.canRequestRefresh == rhs.canRequestRefresh
        }

        mutating func apply(sharedState: NearbyVehicleMapFeatureState) {
            self.sharedState = sharedState
        }

        var title: String {
            "Nearby vehicles"
        }

        var message: String {
            guard let sharedState else {
                return "Preparing the rider-centered nearby vehicle map."
            }

            switch onEnum(of: sharedState.riderLocationState) {
            case .resolving:
                return "Grant while-in-use location access to center discovery around the rider."
            case .available:
                return vehicleCountText
            case .denied:
                return "Location access is required before nearby vehicles can be positioned relative to the rider."
            case let .temporarilyUnavailable(state):
                if state.lastResolvedLocation == nil {
                    return "Rider location is temporarily unavailable, so discovery is blocked."
                }
                return "Live location is temporarily unavailable. Keeping the last resolved rider position."
            }
        }

        var mapContent: NearbyVehicleMapContent {
            guard let riderLocation = riderLocationCoordinate else {
                return .waitingForRider
            }
            return .riderCentered(
                riderLocation: riderLocation,
                vehicles: currentSnapshot?.vehicles.map(NearbyVehicleMapVehicle.init) ?? [],
            )
        }

        var overlay: NearbyVehicleMapOverlay {
            guard let sharedState else { return .none }

            switch onEnum(of: sharedState.mapOverlayState) {
            case .none:
                return .none
            case .refreshingIndicator:
                return .refreshing
            case .staleIndicator:
                return .stale
            case .blockingFailure:
                return .blockingFailure
            }
        }

        var canRequestRefresh: Bool {
            guard riderLocationCoordinate != nil, let sharedState else { return false }

            switch onEnum(of: sharedState.snapshotState) {
            case .loading, .refreshing:
                return false
            case .initial, .loaded, .failed:
                return true
            }
        }

        private var currentSnapshot: FleetSnapshot? {
            guard let sharedState else { return nil }

            switch onEnum(of: sharedState.snapshotState) {
            case .initial, .loading:
                return nil
            case let .loaded(state):
                return state.snapshot
            case let .refreshing(state):
                return state.snapshot
            case let .failed(state):
                return state.previousSnapshot
            }
        }

        private var vehicleCountText: String {
            guard let currentSnapshot else {
                return "Rider location is ready. Load the first rider-centered fleet snapshot."
            }
            return "Showing \(currentSnapshot.vehicles.count) vehicles around the rider."
        }

        private var riderLocationCoordinate: NearbyVehicleMapCoordinate? {
            guard let sharedState else { return nil }

            switch onEnum(of: sharedState.riderLocationState) {
            case .resolving, .denied:
                return nil
            case let .available(state):
                return NearbyVehicleMapCoordinate(location: state.location)
            case let .temporarilyUnavailable(state):
                return state.lastResolvedLocation.map(NearbyVehicleMapCoordinate.init)
            }
        }
    }
}

enum NearbyVehicleMapContent: Equatable {
    case waitingForRider
    case riderCentered(
        riderLocation: NearbyVehicleMapCoordinate,
        vehicles: [NearbyVehicleMapVehicle],
    )
}

struct NearbyVehicleMapCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    init(location: RiderLocation) {
        latitude = location.latitude
        longitude = location.longitude
    }

    init(location: VehicleLocation) {
        latitude = location.latitude
        longitude = location.longitude
    }
}

struct NearbyVehicleMapVehicle: Equatable {
    let location: NearbyVehicleMapCoordinate

    init(vehicle: NearbyVehicle) {
        location = NearbyVehicleMapCoordinate(location: vehicle.location)
    }
}

enum NearbyVehicleMapOverlay: Equatable {
    case none
    case banner(
        headline: String,
        message: String,
    )
    case blocking(
        headline: String,
        message: String,
    )

    static let refreshing =
        NearbyVehicleMapOverlay.banner(
            headline: "Refreshing",
            message: "Keeping the last snapshot visible while the simulated fleet updates.",
        )

    static let stale =
        NearbyVehicleMapOverlay.banner(
            headline: "Snapshot may be stale",
            message: "The last successful fleet snapshot is still visible inside the freshness window.",
        )

    static let blockingFailure =
        NearbyVehicleMapOverlay.blocking(
            headline: "Map unavailable",
            message: "A trustworthy rider-centered vehicle snapshot is not available right now.",
        )

    var blocksMap: Bool {
        if case .blocking = self {
            return true
        }
        return false
    }
}
