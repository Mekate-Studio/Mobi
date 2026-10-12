import Foundation

/// Embedded by the explicit pilot build, never supplied by a scripted launch.
/// Values are provisional unless the source-bound review record is accepted.
struct PilotRuntimeSettings: Decodable, Sendable {
    let repositoryPolicy: String
    let parentReservations: Int
    let nativeJobsPerOwner: Int32
    let composeJobsPerOwner: Int32
    let pollingNanoseconds: UInt64
    let backoffNanoseconds: UInt64
    let shutdownObservationNanoseconds: UInt64

    static let current: Self = {
        guard let url = Bundle.main.url(forResource: "pilot-runtime-settings", withExtension: "json"),
              let bytes = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(Self.self, from: bytes),
              ["main-confined", "shared-operation-mutex"].contains(settings.repositoryPolicy),
              settings.parentReservations > 0, settings.nativeJobsPerOwner > 0,
              settings.composeJobsPerOwner > 0, settings.pollingNanoseconds > 0,
              settings.backoffNanoseconds > 0, settings.shutdownObservationNanoseconds > 0
        else { fatalError("Explicit embedded pilot runtime settings required") }
        return settings
    }()
}
