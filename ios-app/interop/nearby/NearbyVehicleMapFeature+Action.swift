import Foundation
import MobiIOSDependencies

extension NearbyVehicleMapFeature {
    enum LocationBlockedReason: Equatable, Sendable {
        case accessDenied, accessRestricted, servicesDisabled, approximateOnly, temporarilyUnavailable
    }

    enum LocationResolutionResult: Equatable, Sendable {
        case precise(latitude: Double, longitude: Double)
        case blocked(LocationBlockedReason)
        case temporarilyUnavailable
    }

    enum Action: Equatable, Sendable {
        case task
        case locationResolutionResponse(LocationResolutionResult)
        case refreshTapped
        case visibleRefreshDue(nowMillis: Int64)
        case timePassed(nowMillis: Int64)
        case response(UUID, NativeNearbyState)
        case admissionDenied(UUID, AdmissionError)
        case boundaryFailed(UUID, NativeNearbyError)
        case cancelled(UUID)
        case cancelRefresh
        case retire
    }
}
