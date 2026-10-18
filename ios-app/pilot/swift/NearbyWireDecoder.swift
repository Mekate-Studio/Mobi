import Foundation
import MobiNearbyTransport

@MainActor enum NearbyWireDecoder {
    static func copy(_ wire: NearbyTransport.WireState, owner: UUID) throws -> NativeNearbyState {
        try NativeNearbyAccess.validateSchema(wire.schemaVersion)
        guard let overlay = NativeOverlay(rawValue: wire.overlayTag) else { throw NativeNearbyError.invalidWire }
        return try NativeNearbyState(
            owner: owner, handle: wire.id,
            location: location(wire), snapshot: snapshot(wire), overlay: overlay,
            canRefresh: wire.canRefresh, canInteract: wire.canInteract,
        )
    }

    private static func coordinate(_ wire: NearbyTransport.WireState) throws -> NativeCoordinate? {
        switch (wire.latitude, wire.longitude) {
        case (nil, nil): return nil
        case let (.some(latitude), .some(longitude)):
            return NativeCoordinate(latitude: latitude, longitude: longitude)
        default: throw NativeNearbyError.invalidWire
        }
    }

    private static func location(_ wire: NearbyTransport.WireState) throws -> NativeLocation {
        switch try (wire.locationTag, coordinate(wire), wire.blockedReason) {
        case (0, nil, nil): return .resolving
        case let (1, .some(value), nil): return .available(value)
        case (2, nil, nil): return .denied
        case let (3, nil, .some(reason)): return try .blocked(NativeNearbyAccess.decodeBlockedTag(reason))
        case let (4, .some(value), nil): return .temporarilyUnavailable(value)
        case (5, nil, nil): return .unavailable
        default: throw NativeNearbyError.invalidWire
        }
    }

    private static func fleet(_ wire: NearbyTransport.WireState) throws -> NativeFleet? {
        switch (wire.sequence, wire.loadedAt, wire.snapshotLatitude, wire.snapshotLongitude) {
        case (nil, nil, nil, nil):
            guard wire.vehicleCount == 0 else { throw NativeNearbyError.invalidWire }
            return nil
        case let (.some(sequence), .some(loadedAt), .some(latitude), .some(longitude)):
            guard wire.vehicleCount >= 0 else { throw NativeNearbyError.invalidWire }
            let vehicles = (0 ..< wire.vehicleCount).map { index -> NativeVehicle in
                let vehicle = wire.vehicleAt(index: index)
                return NativeVehicle(
                    id: vehicle.id,
                    location: NativeCoordinate(latitude: vehicle.latitude, longitude: vehicle.longitude),
                )
            }
            return NativeFleet(
                sequence: sequence,
                riderLocation: NativeCoordinate(latitude: latitude, longitude: longitude),
                vehicles: vehicles,
                loadedAt: loadedAt,
            )
        default: throw NativeNearbyError.invalidWire
        }
    }

    private static func snapshot(_ wire: NearbyTransport.WireState) throws -> NativeSnapshot {
        let fleet = try fleet(wire)
        let reason = try wire.failureReason.map(NativeNearbyAccess.decodeFailureTag)
        switch (wire.snapshotTag, fleet, reason) {
        case (0, nil, nil): return .initial
        case (1, nil, nil): return .loading
        case let (2, .some(value), nil): return .loaded(value)
        case let (3, .some(value), nil): return .refreshing(value)
        case let (4, .some(value), .some(reason)): return .failedWithSnapshot(value, reason)
        case let (5, nil, .some(reason)): return .failedWithoutSnapshot(reason)
        default: throw NativeNearbyError.invalidWire
        }
    }
}
