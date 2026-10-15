import Foundation
@_implementationOnly import MobiNativeServices

typealias NearbyTransport = ExportedKotlinPackages.studio.mekate.mobi.export.nearby
/// Immutable presentation plus an opaque, owner-scoped Kotlin state reference.
/// No Kotlin wrapper or transport variant registry enters a reducer action.
struct NativeNearbyState: Sendable, Equatable {
    let owner: UUID
    let handle: Int64
    let message: String
    let mapContent: NearbyVehicleMapContent
    let overlay: NearbyVehicleMapOverlay
    let canRefresh: Bool
    let canInteract: Bool

    func sameHandle(as other: Self) -> Bool {
        owner == other.owner && handle == other.handle
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message && lhs.mapContent == rhs.mapContent && lhs.overlay == rhs.overlay &&
            lhs.canRefresh == rhs.canRefresh && lhs.canInteract == rhs.canInteract
    }
}

enum NativeNearbyError: Error,
    Equatable { case wrongOwner, released, retired, invalidResult, invalidInput, observationUnavailable, bridgeFailure }

@MainActor final class NativeNearbyAccess {
    private let supervisor: CompletionDrainSupervisor
    private let admission: AdmissionPool
    private let owner = UUID()
    private let facade: NearbyTransport.NearbyRequestOwner
    private var retired = false
    private var pendingResults: Set<Int64> = []
    init(
        facade: NearbyTransport.NearbyRequestOwner,
        supervisor: CompletionDrainSupervisor,
        admission: AdmissionPool,
    ) {
        self.facade = facade
        self.supervisor = supervisor
        self.admission = admission
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

    func available(_ state: NativeNearbyState, latitude: Double, longitude: Double) throws -> NativeNearbyState {
        guard latitude.isFinite, longitude.isFinite, (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude) else { throw NativeNearbyError.invalidInput }
        return try copy(facade.states.available(
            id: handle(state),
            latitude: latitude,
            longitude: longitude,
        ))
    }

    func blocked(
        _ state: NativeNearbyState,
        _ reason: NearbyVehicleMapFeature.LocationBlockedReason,
    ) throws -> NativeNearbyState {
        try copy(facade.states.blocked(
            id: handle(state),
            reason: reason.sharedValue,
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

    func adoptResult(_ value: NativeNearbyState) throws {
        _ = try handle(value)
        guard pendingResults.remove(value.handle) != nil else { throw NativeNearbyError.invalidResult }
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

    func refresh(_ state: NativeNearbyState, now: Int64) async throws -> NativeNearbyState {
        try Task.checkCancellation(); try validTime(now)
        let stateID = try handle(state)
        let reservation = try admission.reserve(.nearbyRequest)
        let id = facade.beginRefresh(id: stateID, now: now)
        guard id != 0 else { reservation.release(); throw AdmissionError.full }
        var ownsRequest = true
        do {
            let completion = RequestCompletion()
            let token = facade.completion.observe(id: id, observer: completion.signal)
            guard token != 0 else { throw NativeNearbyError.observationUnavailable }
            // Dispose before cleanup takes over the exclusive subscription.
            let value: NativeNearbyState
            do {
                defer { facade.completion.stop(id: id, token: token) }
                try await completion.wait()
                value = try completed(id, didConsume: { ownsRequest = false; reservation.release() })
            }
            return value
        } catch {
            if ownsRequest {
                facade.cancelRequest(id: id)
                let retained = facade
                supervisor.adopt(
                    isCompleted: { retained.poll(id: id).drained },
                    forget: { retained.forgetRequest(id: id) },
                    subscribe: { retained.completion.observe(id: id, observer: $0) },
                    unsubscribe: { retained.completion.stop(id: id, token: $0) },
                    reservation: reservation,
                )
            }
            throw error
        }
    }

    private func completed(_ id: Int64, didConsume: () -> Void) throws -> NativeNearbyState {
        let poll = facade.poll(id: id)
        switch poll.phase {
        case .Running: throw NativeNearbyError.invalidResult
        case .Delivered:
            guard poll.drained else { throw NativeNearbyError.invalidResult }
            let wire = facade.consume(id: id)
            didConsume() // Kotlin removed the request; subsequent copy failure owns only this state handle.
            let result = try copy(wire)
            pendingResults.insert(result.handle)
            return result
        case .Cancelled: throw CancellationError()
        case .BridgeFailure: throw NativeNearbyError.bridgeFailure
        }
    }

    private func copy(_ value: NearbyTransport.NearbyOwnedValue) throws -> NativeNearbyState {
        do { return try NearbyStateCopy.copy(value, owner: owner) } catch {
            facade.states.releaseState(id: value.id)
            throw error
        }
    }
}
