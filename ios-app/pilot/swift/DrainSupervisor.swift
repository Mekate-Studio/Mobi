import Foundation

struct DrainKey: Sendable, Hashable { let owner: UUID; let request: Int64 }
enum DrainState: String, Sendable { case stillDraining, completed }
struct DrainReceipt: Sendable { let key: DrainKey; let state: DrainState }
struct DrainMetrics: Sendable { let active: Int; let accepted: Int; let completed: Int }

@MainActor private final class DrainTicket {
    let isCompleted: @MainActor () -> Bool
    let forget: @MainActor () -> Bool
    var task: Task<Void, Never>?
    init(isCompleted: @escaping @MainActor () -> Bool, forget: @escaping @MainActor () -> Bool) {
        self.isCompleted = isCompleted; self.forget = forget
    }
}

/// App composition-root service. It owns each unfinished request independently
/// of caller cancellation, the access object and the Store. No timeout frees live work.
@MainActor final class DrainSupervisor {
    private let clock: any FacadePollingDriver
    private var tickets: [DrainKey: DrainTicket] = [:]
    private var accepted = 0
    private var completed = 0
    private(set) var startedJobs = 0
    init(clock: any FacadePollingDriver = SystemPollDriver()) {
        self.clock = clock
    }

    func metrics() -> DrainMetrics {
        DrainMetrics(active: tickets.count, accepted: accepted, completed: completed)
    }

    func contains(_ key: DrainKey) -> Bool {
        tickets[key] != nil
    }

    func adopt(
        _ key: DrainKey,
        isCompleted: @escaping @MainActor () -> Bool,
        forget: @escaping @MainActor () -> Bool,
    ) -> DrainReceipt {
        if tickets[key] != nil {
            return DrainReceipt(key: key, state: .stillDraining)
        }
        accepted += 1
        if isCompleted() {
            precondition(forget()); completed += 1
            return DrainReceipt(key: key, state: .completed)
        }
        let ticket = DrainTicket(isCompleted: isCompleted, forget: forget)
        tickets[key] = ticket
        let clock = clock
        let operation: @MainActor @Sendable () async -> Void = { [weak self, ticket] in
            self?.startedJobs += 1
            while !ticket.isCompleted() {
                await cleanupPause(clock)
            }
            precondition(ticket.forget())
            if let self {
                precondition(tickets[key] === ticket)
                tickets.removeValue(forKey: key); completed += 1
            }
            ticket.task = nil
        }
        // Detached does not inherit TCA's task-local dependency context. Execution is
        // still explicitly MainActor; Kotlin wrappers do not transfer to a worker.
        ticket.task = Task.detached(operation: operation)
        return DrainReceipt(key: key, state: .stillDraining)
    }
}
