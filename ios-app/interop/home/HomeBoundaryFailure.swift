import Foundation

/// Failures of the native boundary remain distinct from Kotlin domain failures.
enum HomeBoundaryFailure: Error, Equatable, Sendable {
    case invalidCounter
    case invalidResult
    case observationUnavailable

    var message: String {
        switch self {
        case .invalidCounter:
            "This counter value is outside the supported range."
        case .invalidResult:
            "The counter request could not be completed. Try again."
        case .observationUnavailable:
            "The counter request could not be observed. Try again."
        }
    }
}
