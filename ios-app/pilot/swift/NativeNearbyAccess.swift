import Foundation
import MobiNearbyTransport

typealias NearbyTransport = ExportedKotlinPackages.studio.mekate.mobi.export.nearby
struct NativeCoordinate: Sendable, Equatable { let latitude: Double; let longitude: Double }
enum NativeLocationBlocked: Int32, Sendable,
    CaseIterable { case accessDenied, accessRestricted, servicesDisabled, approximateOnly, temporarilyUnavailable }
enum NativeLocation: Sendable, Equatable {
    case resolving
    case available(NativeCoordinate)
    case denied
    case blocked(NativeLocationBlocked)
    case temporarilyUnavailable(NativeCoordinate)
    case unavailable
}

enum NativeNearbyFailure: Int32, Sendable { case riderLocationUnavailable, repositoryUnavailable, unexpected }
struct NativeVehicle: Sendable, Equatable { let id: String; let location: NativeCoordinate }
struct NativeFleet: Sendable, Equatable {
    let sequence: Int64; let riderLocation: NativeCoordinate; let vehicles: [NativeVehicle]; let loadedAt: Int64
}

enum NativeSnapshot: Sendable, Equatable {
    case initial
    case loading
    case loaded(NativeFleet)
    case refreshing(NativeFleet)
    case failedWithSnapshot(NativeFleet, NativeNearbyFailure)
    case failedWithoutSnapshot(NativeNearbyFailure)
}

enum NativeOverlay: Int32, Sendable { case none, refreshing, stale, blockingFailure }
struct NativeNearbyState: Sendable, Equatable {
    let owner: UUID
    let handle: Int64
    let location: NativeLocation
    let snapshot: NativeSnapshot
    let overlay: NativeOverlay
    let canRefresh: Bool
    let canInteract: Bool
    func sameHandle(as other: Self) -> Bool {
        owner == other.owner && handle == other.handle
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.location == rhs.location && lhs.snapshot == rhs.snapshot && lhs.overlay == rhs.overlay && lhs
            .canRefresh == rhs.canRefresh && lhs.canInteract == rhs.canInteract
    }
}

struct NativeNearbyMetrics: Sendable {
    let retired: Bool; let states: Int32; let requests: Int32; let active: Int32; let accepted: Int32; let delivered: Int32; let cancelled: Int32; let lateRejected: Int32
}

enum NativeNearbyError: Error,
    Equatable { case wrongOwner, released, retired, invalidWire, invalidInput, bridgeFailure }

@MainActor final class NativeNearbyAccess {
    private let supervisor: DrainSupervisor
    private let admission: AdmissionPool
    private let drainOwner = UUID()
    private(set) var lastCancellation: DrainReceipt?
    private let clock: any FacadePollingDriver
    private let owner = UUID()
    private let facade: NearbyTransport.NearbyFacade
    private var retired = false
    private var pendingResults: Set<Int64> = []
    init(
        hub: ExportedKotlinPackages.studio.mekate.mobi.export.nearby.NearbyHub,
        supervisor: DrainSupervisor,
        admission: AdmissionPool,
        clock: any FacadePollingDriver = SystemPollDriver(),
    ) {
        self.supervisor = supervisor; self.admission = admission; self.clock = clock; facade = hub.makeFacade()
    }

    func initial() throws -> NativeNearbyState {
        try requireOpen(); return try copy(facade.states.initialValue())
    }

    private func requireOpen() throws {
        guard !retired else { throw NativeNearbyError.retired }
    }

    private func handle(_ state: NativeNearbyState) throws -> Int64 {
        try requireOpen()
        guard state.owner == owner else { throw NativeNearbyError.wrongOwner }
        guard facade.states.hasState(id: state.handle) else { throw NativeNearbyError.released }
        return state.handle
    }

    func available(_ state: NativeNearbyState, _ location: NativeCoordinate) throws -> NativeNearbyState {
        guard location.latitude.isFinite, location.longitude.isFinite, (-90 ... 90).contains(location.latitude),
              (-180 ... 180).contains(location.longitude) else { throw NativeNearbyError.invalidInput }
        return try copy(facade.states.available(
            id: handle(state),
            latitude: location.latitude,
            longitude: location.longitude,
        ))
    }

    func blocked(
        _ state: NativeNearbyState,
        _ reason: NativeLocationBlocked,
    ) throws -> NativeNearbyState {
        try copy(facade.states.blocked(
            id: handle(state),
            reason: reason.rawValue,
        ))
    }

    func temporary(_ state: NativeNearbyState) throws -> NativeNearbyState {
        try copy(facade.temporary(id: handle(state)))
    }

    func loading(_ state: NativeNearbyState) throws -> NativeNearbyState {
        try copy(facade.states.loading(id: handle(state)))
    }

    func timePassed(
        _ state: NativeNearbyState,
        now: Int64,
    ) throws -> NativeNearbyState {
        try validTime(now); return try copy(facade.states.timePassed(
            id: handle(state),
            now: now,
        ))
    }

    func shouldRefresh(
        _ state: NativeNearbyState,
        now: Int64,
    ) throws -> Bool {
        try validTime(now); return try facade.shouldRefresh(
            id: handle(state),
            now: now,
        )
    }

    private func validTime(_ now: Int64) throws {
        guard now >= 0 else { throw NativeNearbyError.invalidInput }
    }

    func release(_ state: NativeNearbyState) throws {
        try facade.states.releaseState(id: handle(state))
    }

    func adoptResult(_ value: NativeNearbyState) throws {
        _ = try handle(value)
        guard pendingResults.remove(value.handle) != nil else { throw NativeNearbyError.invalidWire }
    }

    func discardUnclaimed(_ value: NativeNearbyState) {
        guard value.owner == owner, pendingResults.remove(value.handle) != nil else { return }
        if !retired {
            facade.states.releaseState(id: value.handle)
        }
    }

    func releaseOwned(_ value: NativeNearbyState) {
        guard value.owner == owner else { return }
        pendingResults.remove(value.handle)
        if !retired {
            facade.states.releaseState(id: value.handle)
        }
    }

    func pendingCount() -> Int {
        pendingResults.count
    }

    func retire() {
        if !retired {
            retired = true; pendingResults.removeAll(); facade.retire()
        }
    }

    func metrics() -> NativeNearbyMetrics {
        let metrics = facade.metrics()
        return NativeNearbyMetrics(
            retired: metrics.retired,
            states: metrics.states,
            requests: metrics.requests,
            active: metrics.active,
            accepted: metrics.accepted,
            delivered: metrics.delivered,
            cancelled: metrics.cancelled,
            lateRejected: metrics.lateRejected,
        )
    }

    func refresh(_ state: NativeNearbyState, now: Int64) async throws -> NativeNearbyState {
        try Task.checkCancellation(); try validTime(now)
        let stateID = try handle(state)
        let reservation = try admission.reserve(.nearbyRequest)
        let id = facade.beginRefresh(id: stateID, now: now)
        guard id != 0 else { reservation.release(); throw AdmissionError.full }
        var ownsRequest = true
        do {
            while true {
                try Task.checkCancellation()
                if let result = try completed(id, didConsume: { ownsRequest = false; reservation.release() }) {
                    return result
                }
                try await clock.wait()
            }
        } catch {
            if ownsRequest {
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
            }
            throw error
        }
    }

    private func completed(_ id: Int64, didConsume: () -> Void) throws -> NativeNearbyState? {
        let poll = facade.poll(id: id)
        switch poll.phase {
        case 0: return nil
        case 1:
            guard poll.drained else { return nil }
            let wire = facade.consume(id: id)
            didConsume() // Kotlin removed the request; subsequent copy failure owns only this state handle.
            do {
                let result = try copy(wire)
                pendingResults.insert(result.handle)
                return result
            } catch {
                facade.states.releaseState(id: wire.id)
                throw error
            }
        case 2: throw CancellationError()
        default: throw NativeNearbyError.bridgeFailure
        }
    }

    static func validateSchema(_ version: Int32) throws {
        guard version == 1 else { throw NativeNearbyError.invalidWire }
    }

    static func decodeBlockedTag(_ tag: Int32) throws -> NativeLocationBlocked {
        guard let value = NativeLocationBlocked(rawValue: tag)
        else { throw NativeNearbyError.invalidWire }; return value
    }

    static func decodeFailureTag(_ tag: Int32) throws -> NativeNearbyFailure {
        guard let value = NativeNearbyFailure(rawValue: tag)
        else { throw NativeNearbyError.invalidWire }; return value
    }

    /// Copy generated wrappers synchronously before any native suspension.
    private func copy(_ wire: NearbyTransport.WireState) throws -> NativeNearbyState {
        try NearbyWireDecoder.copy(wire, owner: owner)
    }
}
