import Foundation

@MainActor protocol FacadePollingDriver: AnyObject, Sendable { func wait() async throws }
@MainActor final class SystemPollDriver: FacadePollingDriver {
    private static var completedWaits = 0
    private static var cancelledWaits = 0
    private static var totalNanoseconds: UInt64 = 0
    private static var minimumNanoseconds: UInt64 = .max
    private static var maximumNanoseconds: UInt64 = 0
    static func observations() -> [String: Any] {
        [
            "scope": "actual_app_system_poll_wait_resumptions",
            "waitResumptions": completedWaits,
            "cancelledResumptions": cancelledWaits,
            "totalNanoseconds": totalNanoseconds,
            "minimumNanoseconds": completedWaits == 0 ? 0 : minimumNanoseconds,
            "maximumNanoseconds": maximumNanoseconds,
        ]
    }

    func wait() async throws {
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            Self.completedWaits += 1
            if Task.isCancelled {
                Self.cancelledWaits += 1
            }
            Self.totalNanoseconds += elapsed
            Self.minimumNanoseconds = min(Self.minimumNanoseconds, elapsed)
            Self.maximumNanoseconds = max(Self.maximumNanoseconds, elapsed)
        }
        try await Task.sleep(for: .nanoseconds(Int64(PilotRuntimeSettings.current.pollingNanoseconds)))
    }
}

/// Private cleanup tasks are never cancelled by public acknowledgement waiters.
/// An unexpected failed driver must not turn into an immediate retry spin.
@MainActor func cleanupPause(_ clock: any FacadePollingDriver) async {
    do {
        try await clock.wait()
    } catch {
        let backoff: @Sendable () async
            -> Void = {
                try? await Task.sleep(for: .nanoseconds(Int64(PilotRuntimeSettings.current.backoffNanoseconds)))
            }
        await Task.detached(operation: backoff).value
    }
}
