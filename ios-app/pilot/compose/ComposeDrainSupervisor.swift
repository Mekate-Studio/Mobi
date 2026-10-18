import Foundation
import MobiSharedUIOwner

struct ComposeDrainSnapshot: Sendable {
    let id: UUID
    let open: Bool
    let drained: Bool
    let active: Int32
    let accepted: Int32
    let delivered: Int32
    let cancelled: Int32
    let finished: Int32
    let retireTransitions: Int32
    let lateRejected: Int32
    let publications: Int32
}

@MainActor private final class ComposeTicket {
    let poll: @MainActor () -> ComposeDrainSnapshot
    var task: Task<Void, Never>?
    init(poll: @escaping @MainActor () -> ComposeDrainSnapshot) {
        self.poll = poll
    }
}

/// App lifetime. Retain only the retired Kotlin owner until its actual
/// job-completion registry drains; no controller, coordinator or AppServices capture.
@MainActor final class ComposeDrainSupervisor {
    private let clock: any FacadePollingDriver
    private var tickets: [UUID: ComposeTicket] = [:]
    private(set) var completedCount = 0
    var active: Int {
        tickets.count
    }

    init(clock: any FacadePollingDriver = SystemPollDriver()) {
        self.clock = clock
    }

    func snapshot(_ id: UUID) -> ComposeDrainSnapshot? {
        tickets[id]?.poll()
    }

    func adopt(_ owner: SharedUIOwner.HomeRouteOwner, onCompletion: @escaping @MainActor () -> Void) -> UUID {
        precondition(!owner.isOpen && !owner.isDrained)
        let id = UUID()
        let ticket = ComposeTicket {
            let value = owner.snapshot()
            return ComposeDrainSnapshot(
                id: id,
                open: value.open,
                drained: value.drained,
                active: value.activeJobs,
                accepted: value.accepted,
                delivered: value.delivered,
                cancelled: value.cancelled,
                finished: value.finished,
                retireTransitions: value.retireTransitions,
                lateRejected: value.lateResultsRejected,
                publications: value.publications,
            )
        }
        tickets[id] = ticket
        let clock = clock
        let operation: @MainActor @Sendable () async -> Void = { [weak self, ticket] in
            while !ticket.poll().drained {
                await cleanupPause(clock)
            }
            if let self {
                precondition(tickets[id] === ticket)
                completedCount += 1; tickets.removeValue(forKey: id)
            }
            onCompletion()
            ticket.task = nil
        }
        ticket.task = Task.detached(operation: operation)
        return id
    }
}
