import Foundation

/// Cancellation delivery is independent of the cancelled TCA Send task.
@MainActor final class CancellationRelay {
    var sink: (@MainActor (UUID) -> Void)?
    func deliver(_ request: UUID) {
        sink?(request)
    }
}
