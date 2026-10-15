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
        var boundaryFailure: NativeNearbyError?

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.sharedState == rhs.sharedState && lhs.activeRequest == rhs.activeRequest &&
                lhs.previousState == rhs.previousState && lhs.retired == rhs.retired &&
                lhs.admissionFailure == rhs.admissionFailure && lhs.boundaryFailure == rhs.boundaryFailure
        }

        var title: String {
            "Nearby vehicles"
        }

        var message: String {
            boundaryFailure?.message ?? admissionFailure?.message ?? sharedState?.message ??
                "Preparing the rider-centered nearby vehicle map."
        }

        var canInteractWithVehicles: Bool {
            !retired && sharedState?.canInteract == true
        }

        var refreshLabel: String {
            admissionFailure == .closed ? "Session ended" :
                admissionFailure != nil || boundaryFailure != nil ? "Try nearby again" : "Refresh nearby vehicles"
        }

        var canRequestRefresh: Bool {
            !retired && admissionFailure != .closed && sharedState?.canRefresh == true
        }

        var mapContent: NearbyVehicleMapContent {
            sharedState?.mapContent ?? .waitingForRider
        }

        var overlay: NearbyVehicleMapOverlay {
            sharedState?.overlay ?? .none
        }
    }
}

enum NearbyVehicleMapContent: Equatable, Sendable { case waitingForRider, riderCentered(scene: NearbyVehicleMapScene) }
struct NearbyVehicleMapScene: Equatable, Sendable {
    let camera: NearbyVehicleMapCamera
    let riderMarker: NearbyVehicleMapRiderMarker
    let vehicleMarkers: [NearbyVehicleMapVehicleMarker]
    init(riderLocation: NearbyVehicleMapCoordinate, vehicles: [NearbyVehicleMapVehicleMarker]) {
        let coordinate = riderLocation
        camera = NearbyVehicleMapCamera(target: coordinate, zoom: 15)
        riderMarker = NearbyVehicleMapRiderMarker(coordinate: coordinate)
        vehicleMarkers = vehicles
    }
}

struct NearbyVehicleMapCamera: Equatable, Sendable { let target: NearbyVehicleMapCoordinate; let zoom: Double }
struct NearbyVehicleMapCoordinate: Equatable, Sendable {
    let latitude: Double; let longitude: Double
}

struct NearbyVehicleMapRiderMarker: Equatable, Sendable { let coordinate: NearbyVehicleMapCoordinate }
struct NearbyVehicleMapVehicleMarker: Equatable, Sendable {
    let id: String; let coordinate: NearbyVehicleMapCoordinate
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
