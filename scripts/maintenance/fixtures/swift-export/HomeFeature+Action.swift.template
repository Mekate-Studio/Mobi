import Foundation
import MobiIOSDependencies

extension HomeFeature {
    enum Action: Equatable, Sendable {
        case task
        case refreshTapped
        case response(UUID, HomeCounterLoadable)
        case admissionDenied(UUID, AdmissionError)
        case cancelled(UUID)
        case cancelRefresh
        case retire
    }
}
