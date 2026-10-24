@preconcurrency import MobiCore
import MobiIOSDependencies
@preconcurrency import MobiNearby

extension NearbyVehicleMapFeature {
    private enum Content {
        case preparing
        case checkingLocation(NearbyVehicleMapFeatureState)
        case ready(NearbyVehicleMapFeatureState)
    }

    @ObservableState
    struct State: Equatable {
        private var content = Content.preparing

        var sharedState: NearbyVehicleMapFeatureState? {
            switch content {
            case .preparing:
                nil
            case let .checkingLocation(state), let .ready(state):
                state
            }
        }

        static func == (
            lhs: State,
            rhs: State,
        ) -> Bool {
            lhs.message == rhs.message &&
                lhs.mapContent == rhs.mapContent &&
                lhs.overlay == rhs.overlay &&
                lhs.canRequestRefresh == rhs.canRequestRefresh &&
                lhs.canInteractWithVehicles == rhs.canInteractWithVehicles
        }

        mutating func apply(sharedState: NearbyVehicleMapFeatureState) {
            content = .ready(sharedState)
        }

        mutating func beginLocationResolution() {
            guard hasResolvedRiderLocation, let sharedState else { return }
            content = .checkingLocation(cancelledRefreshState(sharedState))
        }

        mutating func applyRefreshResult(_ result: State) {
            guard let current = sharedState, let refreshed = result.sharedState else { return }

            apply(sharedState: refreshed.copy(
                riderLocationState: current.riderLocationState,
                snapshotState: refreshed.snapshotState,
                mapOverlayState: refreshed.mapOverlayState,
            ))
        }

        var title: String {
            "Nearby vehicles"
        }

        var message: String {
            if case .checkingLocation = content {
                return currentSnapshot == nil
                    ? "Checking precise rider location before loading nearby vehicles."
                    : Self.checkingLocationMessage
            }
            guard let sharedState else {
                return "Preparing the rider-centered nearby vehicle map."
            }

            switch sharedState.riderLocationState.sealedType() {
            case .resolving:
                return "Grant while-in-use location access to center discovery around the rider."
            case .available:
                return vehicleCountText
            case .denied:
                return blockedLocationMessage(.AccessDenied)
            case let .blocked(state):
                return blockedLocationMessage(state.value.reason)
            case .temporarilyUnavailable:
                return "Live location is temporarily unavailable. Keeping the last resolved rider position."
            case .unavailable:
                return "Rider location is temporarily unavailable, so discovery is blocked."
            }
        }

        var hasResolvedRiderLocation: Bool {
            guard case .ready = content else { return false }
            return riderLocation != nil
        }

        var canInteractWithVehicles: Bool {
            guard hasResolvedRiderLocation, let sharedState else { return false }
            guard case .blockingFailure = sharedState.mapOverlayState.sealedType() else {
                return true
            }
            return false
        }

        var mapContent: NearbyVehicleMapContent {
            if case .checkingLocation = content, currentSnapshot == nil {
                return .waitingForRider
            }
            guard let riderLocation else {
                return .waitingForRider
            }
            return .riderCentered(
                scene: NearbyVehicleMapScene(
                    riderLocation: riderLocation,
                    vehicles: currentSnapshot?.vehicles ?? [],
                ),
            )
        }

        var overlay: NearbyVehicleMapOverlay {
            if case .checkingLocation = content {
                return currentSnapshot == nil
                    ? .none
                    : .banner(headline: "Checking location", message: Self.checkingLocationMessage)
            }
            guard let sharedState else { return .none }

            switch sharedState.mapOverlayState.sealedType() {
            case .none:
                return .none
            case .refreshingIndicator:
                return .refreshing
            case .staleIndicator:
                return .stale
            case .blockingFailure:
                switch sharedState.snapshotState.sealedType() {
                case let .failedWithSnapshot(state):
                    return state.value.reason.blockingOverlay
                case let .failedWithoutSnapshot(state):
                    return state.value.reason.blockingOverlay
                case .initial, .loading, .loaded, .refreshing:
                    return .blockingFailure
                }
            }
        }

        var canRequestRefresh: Bool {
            guard hasResolvedRiderLocation, let sharedState else { return false }

            switch sharedState.snapshotState.sealedType() {
            case .loading, .refreshing:
                return false
            case .initial, .loaded, .failedWithSnapshot, .failedWithoutSnapshot:
                return true
            }
        }

        private static let checkingLocationMessage =
            "Keeping the last snapshot visible while precise rider location is checked."

        private var currentSnapshot: FleetSnapshot? {
            guard let sharedState else { return nil }

            switch sharedState.snapshotState.sealedType() {
            case .initial, .loading:
                return nil
            case let .loaded(state):
                return state.value.snapshot
            case let .refreshing(state):
                return state.value.snapshot
            case let .failedWithSnapshot(state):
                return state.value.snapshot
            case .failedWithoutSnapshot:
                return nil
            }
        }

        private var vehicleCountText: String {
            guard let currentSnapshot else {
                return "Rider location is ready. Load the first rider-centered fleet snapshot."
            }
            return "Showing \(currentSnapshot.vehicles.count) vehicles around the rider."
        }

        private var riderLocation: RiderLocation? {
            guard let sharedState else { return nil }

            switch sharedState.riderLocationState.sealedType() {
            case .resolving, .denied, .blocked:
                return nil
            case let .available(state):
                return state.value.location
            case let .temporarilyUnavailable(state):
                return state.value.location
            case .unavailable:
                return nil
            }
        }

        private func blockedLocationMessage(_ reason: RiderLocationBlockedReason) -> String {
            switch reason {
            case .AccessDenied:
                "Precise location access is required before nearby vehicles can be positioned relative to the rider."
            case .AccessRestricted:
                "Precise location is restricted on this device, so nearby vehicle discovery is blocked."
            case .ServicesDisabled:
                "Location services are unavailable, so nearby vehicle discovery is blocked."
            case .ApproximateOnly:
                "Precise location is required for nearby vehicle discovery."
            case .TemporarilyUnavailable:
                "Rider location is temporarily unavailable, so discovery is blocked."
            }
        }
    }
}

enum NearbyVehicleMapContent: Equatable {
    case waitingForRider
    case riderCentered(scene: NearbyVehicleMapScene)
}

struct NearbyVehicleMapScene: Equatable {
    let camera: NearbyVehicleMapCamera
    let riderMarker: NearbyVehicleMapRiderMarker
    let vehicleMarkers: [NearbyVehicleMapVehicleMarker]

    init(
        riderLocation: RiderLocation,
        vehicles: [NearbyVehicle],
    ) {
        let riderCoordinate = NearbyVehicleMapCoordinate(location: riderLocation)
        camera = NearbyVehicleMapCamera(
            target: riderCoordinate,
            zoom: 15,
        )
        riderMarker = NearbyVehicleMapRiderMarker(coordinate: riderCoordinate)
        vehicleMarkers = vehicles.map(NearbyVehicleMapVehicleMarker.init(vehicle:))
    }
}

struct NearbyVehicleMapCamera: Equatable {
    let target: NearbyVehicleMapCoordinate
    let zoom: Double
}

struct NearbyVehicleMapCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    init(
        latitude: Double,
        longitude: Double,
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(location: RiderLocation) {
        latitude = location.latitude
        longitude = location.longitude
    }

    init(location: VehicleLocation) {
        latitude = location.latitude
        longitude = location.longitude
    }
}

struct NearbyVehicleMapRiderMarker: Equatable {
    let coordinate: NearbyVehicleMapCoordinate
}

struct NearbyVehicleMapVehicleMarker: Equatable {
    let id: String
    let coordinate: NearbyVehicleMapCoordinate

    init(vehicle: NearbyVehicle) {
        id = vehicle.id.value
        coordinate = NearbyVehicleMapCoordinate(location: vehicle.location)
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
            message: "Precise rider location is required before nearby vehicle actions are available.",
        )

    var blocksMap: Bool {
        if case .blocking = self {
            return true
        }
        return false
    }
}

private extension NearbyVehicleMapFailureReason {
    var blockingOverlay: NearbyVehicleMapOverlay {
        switch self {
        case .RiderLocationUnavailable:
            .blockingFailure
        case .RepositoryUnavailable:
            .blocking(
                headline: "Map unavailable",
                message: "The fleet repository could not load nearby vehicles. Try refreshing again.",
            )
        case .Unexpected:
            .blocking(
                headline: "Map unavailable",
                message: "Something went wrong while loading nearby vehicles. Try refreshing again.",
            )
        }
    }
}
