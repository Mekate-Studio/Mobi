import Foundation
@_implementationOnly import MobiHome
@_implementationOnly import MobiNativeServices

typealias HomeTransport = ExportedKotlinPackages.studio.mekate.mobi.export.home

/// Generated wrappers are private and accessed only by synchronous Main calls.
/// Async callers receive the feature's existing native presentation value.
@MainActor final class NativeHomeAccess {
    private let facade: HomeTransport.HomeRequestOwner
    private let supervisor: CompletionDrainSupervisor
    private let admission: AdmissionPool

    init(
        facade: HomeTransport.HomeRequestOwner,
        supervisor: CompletionDrainSupervisor,
        admission: AdmissionPool,
    ) {
        self.facade = facade
        self.supervisor = supervisor
        self.admission = admission
    }

    func initialValue() throws -> HomeCounterLoadable {
        guard let value = facade.initialValue() else { throw AdmissionError.closed }
        return HomeCounterLoadable(sharedValue: value.counterLoadable)
    }

    func loadingValue(_ current: Int) throws -> HomeCounterLoadable {
        guard let current = Int32(exactly: current) else { throw HomeBoundaryFailure.invalidCounter }
        guard let value = facade.loadingValue(current: current) else { throw AdmissionError.closed }
        return HomeCounterLoadable(sharedValue: value.counterLoadable)
    }

    func retire() {
        facade.retire()
    }

    func refresh(_ current: Int) async throws -> HomeCounterLoadable {
        try Task.checkCancellation()
        guard let current = Int32(exactly: current) else { throw HomeBoundaryFailure.invalidCounter }
        guard !facade.metrics().retired else { throw AdmissionError.closed }
        let reservation = try admission.reserve(.homeRequest)
        let id = facade.beginRefresh(current: current)
        guard id != 0 else { reservation.release(); throw AdmissionError.full }
        do {
            let value = try await completedValue(id)
            guard facade.forgetRequest(id: id) else { throw HomeBoundaryFailure.invalidResult }
            reservation.release()
            return value
        } catch {
            facade.cancelRequest(id: id)
            // Capture the facade and reservation, never this access object/Store.
            let retained = facade
            supervisor.adopt(
                isCompleted: { retained.poll(id: id).drained },
                forget: { retained.forgetRequest(id: id) },
                subscribe: { retained.completion.observe(id: id, observer: $0) },
                unsubscribe: { retained.completion.stop(id: id, token: $0) },
                reservation: reservation,
            )
            throw error
        }
    }

    private func completedValue(_ id: Int64) async throws -> HomeCounterLoadable {
        let completion = RequestCompletion()
        let token = facade.completion.observe(id: id, observer: completion.signal)
        guard token != 0 else { throw HomeBoundaryFailure.observationUnavailable }
        defer { facade.completion.stop(id: id, token: token) }
        try await completion.wait()
        return try copyCompletedValue(id)
    }

    private func copyCompletedValue(_ id: Int64) throws -> HomeCounterLoadable {
        let snapshot = facade.poll(id: id)
        switch snapshot.phase {
        case .Delivered:
            guard snapshot.drained, let value = snapshot.value else { throw HomeBoundaryFailure.invalidResult }
            return HomeCounterLoadable(sharedValue: value.counterLoadable)
        case .Cancelled:
            throw CancellationError()
        case .Running, .BridgeFailure:
            throw HomeBoundaryFailure.invalidResult
        }
    }
}
