import Foundation
import MobiIOSDependencies

extension NearbyVehicleMapFeature {
    @ObservableState
    struct State: Equatable {
        var sharedState: NativeNearbyState?
        let cancellationID = UUID()
        var activeRequest: UUID?
        var previousState: NativeNearbyState?
        var retired = false
        var admissionFailure: AdmissionError?
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.sharedState == rhs.sharedState && lhs.activeRequest == rhs.activeRequest && lhs.previousState == rhs
                .previousState && lhs.retired == rhs.retired && lhs.admissionFailure == rhs.admissionFailure
        }

        var title: String {
            "Nearby vehicles"
        }

        var message: String {
            if let admissionFailure {
                return admissionFailure.message
            }
            guard let sharedState else { return "Preparing the rider-centered nearby vehicle map." }
            switch sharedState.location {
            case .resolving: return "Grant while-in-use location access to center discovery around the rider."
            case .available: return vehicleCountText
            case .denied: return blockedLocationMessage(.accessDenied)
            case let .blocked(reason): return blockedLocationMessage(reason)
            case .temporarilyUnavailable: return "Live location is temporarily unavailable. Keeping the last resolved rider position."
            case .unavailable: return "Rider location is temporarily unavailable, so discovery is blocked."
            }
        }

        var canInteractWithVehicles: Bool {
            !retired && sharedState?.canInteract == true
        }

        var refreshLabel: String {
            admissionFailure == .full ? "Try nearby again" : admissionFailure == .closed ? "Session ended" :
                "Refresh nearby vehicles"
        }

        var canRequestRefresh: Bool {
            !retired && admissionFailure != .closed && sharedState?.canRefresh == true
        }

        var mapContent: NearbyVehicleMapContent {
            guard let location = riderLocation else { return .waitingForRider }
            return .riderCentered(scene: NearbyVehicleMapScene(
                riderLocation: location,
                vehicles: currentSnapshot?.vehicles ?? [],
            ))
        }

        var overlay: NearbyVehicleMapOverlay {
            switch sharedState?.overlay {
            case nil, .none?: .none
            case .refreshing?: .refreshing
            case .stale?: .stale
            case .blockingFailure?: .blockingFailure
            }
        }

        var currentSnapshot: NativeFleet? {
            switch sharedState?.snapshot {
            case let .loaded(value)?, let .refreshing(value)?, let .failedWithSnapshot(value, _)?: value
            case nil, .initial?, .loading?, .failedWithoutSnapshot?: nil
            }
        }

        private var vehicleCountText: String {
            guard let snapshot = currentSnapshot
            else { return "Rider location is ready. Load the first rider-centered fleet snapshot." }
            return "Showing \(snapshot.vehicles.count) vehicles around the rider."
        }

        private var riderLocation: NativeCoordinate? {
            switch sharedState?.location {
            case let .available(value)?, let .temporarilyUnavailable(value)?: value
            case nil, .resolving?, .denied?, .blocked?, .unavailable?: nil
            }
        }

        private func blockedLocationMessage(_ reason: NativeLocationBlocked) -> String {
            switch reason {
            case .accessDenied: "Precise location access is required before nearby vehicles can be positioned relative to the rider."
            case .accessRestricted: "Precise location is restricted on this device, so nearby vehicle discovery is blocked."
            case .servicesDisabled: "Location services are unavailable, so nearby vehicle discovery is blocked."
            case .approximateOnly: "Precise location is required for nearby vehicle discovery."
            case .temporarilyUnavailable: "Rider location is temporarily unavailable, so discovery is blocked."
            }
        }
    }
}

enum NearbyVehicleMapContent: Equatable, Sendable { case waitingForRider, riderCentered(scene: NearbyVehicleMapScene) }
struct NearbyVehicleMapScene: Equatable, Sendable {
    let camera: NearbyVehicleMapCamera
    let riderMarker: NearbyVehicleMapRiderMarker
    let vehicleMarkers: [NearbyVehicleMapVehicleMarker]
    init(riderLocation: NativeCoordinate, vehicles: [NativeVehicle]) {
        let coordinate = NearbyVehicleMapCoordinate(location: riderLocation)
        camera = NearbyVehicleMapCamera(target: coordinate, zoom: 15)
        riderMarker = NearbyVehicleMapRiderMarker(coordinate: coordinate)
        vehicleMarkers = vehicles.map(NearbyVehicleMapVehicleMarker.init(vehicle:))
    }
}

struct NearbyVehicleMapCamera: Equatable, Sendable { let target: NearbyVehicleMapCoordinate; let zoom: Double }
struct NearbyVehicleMapCoordinate: Equatable, Sendable {
    let latitude: Double; let longitude: Double
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude; self.longitude = longitude
    }

    init(location: NativeCoordinate) {
        latitude = location.latitude; longitude = location.longitude
    }
}

struct NearbyVehicleMapRiderMarker: Equatable, Sendable { let coordinate: NearbyVehicleMapCoordinate }
struct NearbyVehicleMapVehicleMarker: Equatable, Sendable {
    let id: String; let coordinate: NearbyVehicleMapCoordinate
    init(vehicle: NativeVehicle) {
        id = vehicle.id; coordinate = NearbyVehicleMapCoordinate(location: vehicle.location)
    }
}

enum NearbyVehicleMapOverlay: Equatable, Sendable {
    case none, banner(headline: String, message: String), blocking(headline: String, message: String)
    static let refreshing = Self.banner(
        headline: "Refreshing",
        message: "Keeping the last snapshot visible while the simulated fleet updates.",
    )
    static let stale = Self.banner(
        headline: "Snapshot may be stale",
        message: "The last successful fleet snapshot is still visible inside the freshness window.",
    )
    static let blockingFailure = Self.blocking(
        headline: "Map unavailable",
        message: "Precise rider location is required before nearby vehicle actions are available.",
    )
    var blocksMap: Bool {
        if case .blocking = self {
            return true
        }; return false
    }
}
