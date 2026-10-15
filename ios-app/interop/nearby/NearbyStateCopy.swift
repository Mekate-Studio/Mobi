import Foundation
@_implementationOnly import MobiCore
@_implementationOnly import MobiNativeServices
@_implementationOnly import MobiNearby

typealias Nearby = ExportedKotlinPackages.studio.mekate.mobi.feature.nearbyvehiclemap
private typealias Core = ExportedKotlinPackages.studio.mekate.mobi.core
private typealias SnapshotPresentation = (message: String, vehicles: [NearbyVehicleMapVehicleMarker])

/// One synchronous Main-confined copy into the actual native map presentation.
/// Each generated sealed switch is exhaustive; there is no fallback state/tag.
@MainActor enum NearbyStateCopy {
    static func copy(_ owned: NearbyTransport.NearbyOwnedValue, owner: UUID) throws -> NativeNearbyState {
        let state = owned.value
        let snapshot = try snapshotPresentation(state.snapshotState)
        let rider: NearbyVehicleMapCoordinate?
        let message: String
        switch state.riderLocationState.sealedType() {
        case .resolving:
            rider = nil
            message = "Grant while-in-use location access to center discovery around the rider."
        case let .available(value):
            rider = try coordinate(value.value.location.latitude, value.value.location.longitude)
            message = snapshot.message
        case .denied:
            rider = nil
            message = blockedMessage(.AccessDenied)
        case let .blocked(value):
            rider = nil
            message = blockedMessage(value.value.reason)
        case let .temporarilyUnavailable(value):
            rider = try coordinate(value.value.location.latitude, value.value.location.longitude)
            message = "Live location is temporarily unavailable. Keeping the last resolved rider position."
        case .unavailable:
            rider = nil
            message = "Rider location is temporarily unavailable, so discovery is blocked."
        }
        let overlay: NearbyVehicleMapOverlay = switch state.mapOverlayState.sealedType() {
        case .none: .none
        case .refreshingIndicator: .refreshing
        case .staleIndicator: .stale
        case .blockingFailure: .blockingFailure
        }
        return NativeNearbyState(
            owner: owner, handle: owned.id, message: message,
            mapContent: rider.map { .riderCentered(scene: NearbyVehicleMapScene(
                riderLocation: $0, vehicles: snapshot.vehicles,
            )) } ?? .waitingForRider,
            overlay: overlay, canRefresh: owned.canRefresh, canInteract: owned.canInteract,
        )
    }

    private static func snapshotPresentation(
        _ state: any Nearby.NearbyVehicleSnapshotState,
    ) throws -> SnapshotPresentation {
        switch state.sealedType() {
        case .initial, .loading:
            ("Rider location is ready. Load the first rider-centered fleet snapshot.", [])
        case let .loaded(value): try fleet(value.value.snapshot)
        case let .refreshing(value): try fleet(value.value.snapshot)
        case let .failedWithSnapshot(value):
            try (failureMessage(value.value.reason), fleet(value.value.snapshot).vehicles)
        case let .failedWithoutSnapshot(value): (failureMessage(value.value.reason), [])
        }
    }

    private static func fleet(_ snapshot: Core.FleetSnapshot) throws -> SnapshotPresentation {
        _ = try coordinate(snapshot.riderLocation.latitude, snapshot.riderLocation.longitude)
        guard snapshot.sequence >= 0, snapshot.loadedAtMillis >= 0 else { throw NativeNearbyError.invalidResult }
        let vehicles = try snapshot.vehicles.map { vehicle in
            try NearbyVehicleMapVehicleMarker(
                id: vehicle.id.value,
                coordinate: coordinate(vehicle.location.latitude, vehicle.location.longitude),
            )
        }
        return ("Showing \(vehicles.count) vehicles around the rider.", vehicles)
    }

    private static func coordinate(_ latitude: Double, _ longitude: Double) throws -> NearbyVehicleMapCoordinate {
        guard latitude.isFinite, longitude.isFinite, (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude) else { throw NativeNearbyError.invalidResult }
        return NearbyVehicleMapCoordinate(latitude: latitude, longitude: longitude)
    }

    private static func failureMessage(_ reason: Nearby.NearbyVehicleMapFailureReason) -> String {
        switch reason {
        case .RiderLocationUnavailable: "Resolve rider location before refreshing nearby vehicles."
        case .RepositoryUnavailable: "Nearby vehicles are unavailable. Try refreshing again."
        case .Unexpected: "Nearby vehicles could not be refreshed. Try again."
        }
    }

    private static func blockedMessage(_ reason: Nearby.RiderLocationBlockedReason) -> String {
        switch reason {
        case .AccessDenied: "Precise location access is required before nearby vehicles can be positioned relative to the rider."
        case .AccessRestricted: "Precise location is restricted on this device, so nearby vehicle discovery is blocked."
        case .ServicesDisabled: "Location services are unavailable, so nearby vehicle discovery is blocked."
        case .ApproximateOnly: "Precise location is required for nearby vehicle discovery."
        case .TemporarilyUnavailable: "Rider location is temporarily unavailable, so discovery is blocked."
        }
    }
}

extension NearbyVehicleMapFeature.LocationBlockedReason {
    @MainActor var sharedValue: Nearby.RiderLocationBlockedReason {
        switch self {
        case .accessDenied: .AccessDenied
        case .accessRestricted: .AccessRestricted
        case .servicesDisabled: .ServicesDisabled
        case .approximateOnly: .ApproximateOnly
        case .temporarilyUnavailable: .TemporarilyUnavailable
        }
    }
}

extension NativeNearbyError {
    var message: String {
        switch self {
        case .retired: "This nearby session has ended."
        case .invalidInput: "Nearby received an invalid location or time. Try again."
        case .wrongOwner, .released, .invalidResult, .observationUnavailable, .bridgeFailure:
            "Nearby could not read the shared result. Try again."
        }
    }
}
