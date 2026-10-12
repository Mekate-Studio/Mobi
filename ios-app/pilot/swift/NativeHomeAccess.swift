import Foundation
import KotlinModules
import MobiHomeTransport

typealias HomeTransport = ExportedKotlinPackages.studio.mekate.mobi.export.home

enum NativeHomeFailure: Sendable, Equatable { case repositoryUnavailable, unexpected }
enum NativeHomeValue: Sendable, Equatable {
    case initial
    case loading(Int32?)
    case loaded(Int32)
    case error(Int32?, NativeHomeFailure)
}

enum NativeFacadeError: Error { case retired, invalidSnapshot, bridgeFailure }

/// Every generated wrapper stays behind this actor's synchronous calls.
@MainActor final class NativeHomeAccess {
    private let supervisor: DrainSupervisor
    private let admission: AdmissionPool
    private let drainOwner = UUID()
    private(set) var lastCancellation: DrainReceipt?
    private let clock: any FacadePollingDriver
    private let facade: HomeTransport.HomeFacade
    init(
        facade: HomeTransport.HomeFacade,
        supervisor: DrainSupervisor,
        admission: AdmissionPool,
        clock: any FacadePollingDriver = SystemPollDriver(),
    ) {
        self.supervisor = supervisor; self.admission = admission; self.clock = clock; self.facade = facade
    }

    func usesService(_ service: HomeFeatureService) -> Bool {
        facade.usesService(other: service)
    }

    func initialValue() throws -> NativeHomeValue {
        guard let snapshot = facade.initialValue()
        else { throw NativeFacadeError.retired }; return try value(snapshot)
    }

    func loadingValue(_ current: Int32) throws -> NativeHomeValue {
        guard let snapshot = facade
            .loadingValue(current: current) else { throw NativeFacadeError.retired }; return try value(snapshot)
    }

    func retire() {
        facade.retire()
    }

    func metrics() -> HomeTransport.FacadeMetrics {
        facade.metrics()
    }

    func refresh(_ current: Int32) async throws -> NativeHomeValue {
        try Task.checkCancellation()
        guard !facade.metrics().retired else { throw AdmissionError.closed }
        let reservation = try admission.reserve(.homeRequest)
        let id = facade.beginRefresh(current: current)
        guard id != 0 else { reservation.release(); throw AdmissionError.full }
        do {
            while true {
                try Task.checkCancellation()
                // Keep this wrapper in a synchronous lexical scope before any await.
                if let result = try completedValue(id) {
                    guard facade.forgetRequest(id: id) else { throw NativeFacadeError.bridgeFailure }
                    reservation.release()
                    return result
                }
                try await clock.wait()
            }
        } catch {
            facade.cancelRequest(id: id)
            // Transfer only the Kotlin facade to an independently owned MainActor ticket.
            // This caller acknowledges cancellation without claiming Kotlin completion.
            let retainedFacade = facade
            lastCancellation = supervisor.adopt(
                DrainKey(owner: drainOwner, request: id),
                isCompleted: { retainedFacade.poll(id: id).drained },
                forget: {
                    let forgotten = retainedFacade.forgetRequest(id: id)
                    if forgotten {
                        reservation.release()
                    }
                    return forgotten
                },
            )
            throw error
        }
    }

    private func completedValue(_ id: Int64) throws -> NativeHomeValue? {
        let snapshot = facade.poll(id: id)
        switch snapshot.phase {
        case 0: return nil
        case 1:
            guard snapshot.drained else { return nil }
            guard let shared = snapshot.value else { throw NativeFacadeError.invalidSnapshot }
            return try value(shared)
        case 2: throw CancellationError()
        default: throw NativeFacadeError.bridgeFailure
        }
    }

    private func value(_ snapshot: HomeTransport.NativeHomeSnapshot) throws -> NativeHomeValue {
        switch snapshot.tag {
        case 0:
            guard snapshot.value == nil, snapshot.reason == nil else { throw NativeFacadeError.invalidSnapshot }
            return .initial
        case 1:
            guard snapshot.reason == nil else { throw NativeFacadeError.invalidSnapshot }
            return .loading(snapshot.value)
        case 2:
            guard let number = snapshot.value, snapshot.reason == nil else { throw NativeFacadeError.invalidSnapshot }
            return .loaded(number)
        case 3:
            return try .error(snapshot.value, failure(snapshot.reason))
        default: throw NativeFacadeError.invalidSnapshot
        }
    }

    private func failure(_ tag: Int32?) throws -> NativeHomeFailure {
        switch tag {
        case 0: return .repositoryUnavailable
        case 1: return .unexpected
        default: throw NativeFacadeError.invalidSnapshot
        }
    }
}
