import Foundation

/// The signal captures only a thread-safe continuation. It reads no Kotlin or
/// actor-owned state and remains harmless if disposal races with a callback.
@MainActor final class RequestCompletion {
    private let stream: AsyncStream<Void>
    let signal: @Sendable () -> Void

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.stream = stream
        signal = {
            continuation.yield()
            continuation.finish()
        }
    }

    func wait() async throws {
        for await _ in stream {
            try Task.checkCancellation()
            return
        }
        try Task.checkCancellation()
        throw HomeBoundaryFailure.observationUnavailable
    }
}

struct CompletionDrainMetrics: Sendable {
    let active: Int
    let accepted: Int
    let completed: Int
}

/// Retains unfinished backend work independently of a feature owner or TCA task.
/// Cancellation acknowledges the caller; only completion releases its capacity.
@MainActor final class CompletionDrainSupervisor {
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var accepted = 0
    private var completed = 0

    func metrics() -> CompletionDrainMetrics {
        CompletionDrainMetrics(active: tasks.count, accepted: accepted, completed: completed)
    }

    func adopt(
        isCompleted: @escaping @MainActor () -> Bool,
        forget: @escaping @MainActor () -> Bool,
        subscribe: @escaping @MainActor (@escaping @Sendable () -> Void) -> Int64,
        unsubscribe: @escaping @MainActor (Int64) -> Void,
        reservation: AdmissionReservation,
    ) {
        accepted += 1
        if isCompleted() {
            precondition(forget())
            reservation.release()
            completed += 1
            return
        }
        let completion = RequestCompletion()
        let token = subscribe(completion.signal)
        // This internal transfer has exclusive ownership after caller disposal.
        precondition(token != 0, "Cleanup must retain a completion subscription")
        let id = UUID()
        let operation: @MainActor @Sendable () async -> Void = { [weak self] in
            // Detached cleanup does not inherit caller cancellation or TCA locals.
            do {
                try await completion.wait()
            } catch {
                preconditionFailure("Independent cleanup was unexpectedly cancelled")
            }
            precondition(isCompleted())
            unsubscribe(token)
            precondition(forget())
            reservation.release()
            self?.tasks.removeValue(forKey: id)
            self?.completed += 1
        }
        tasks[id] = Task.detached(operation: operation)
    }
}
