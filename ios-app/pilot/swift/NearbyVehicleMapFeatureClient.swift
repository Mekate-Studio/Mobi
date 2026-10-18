import Foundation
import MobiIOSDependencies

struct NearbyVehicleMapFeatureClient: Sendable {
    var initialState: @Sendable () throws -> NativeNearbyState
    var preciseLocationResolvedState: @Sendable (NativeNearbyState, Double, Double) throws -> NativeNearbyState
    var locationBlockedState: @Sendable (NativeNearbyState, NearbyVehicleMapFeature.LocationBlockedReason) throws
        -> NativeNearbyState
    var locationTemporarilyUnavailableState: @Sendable (NativeNearbyState) throws -> NativeNearbyState
    var loadingState: @Sendable (NativeNearbyState) throws -> NativeNearbyState
    var refresh: @Sendable (NativeNearbyState, Int64) async throws -> NativeNearbyState
    var shouldRefresh: @Sendable (NativeNearbyState, Int64) throws -> Bool
    var timePassed: @Sendable (NativeNearbyState, Int64) throws -> NativeNearbyState
    var adopt: @Sendable (NativeNearbyState) throws -> Void
    var release: @Sendable (NativeNearbyState) -> Void
    var discard: @Sendable (NativeNearbyState) -> Void
    var discardAfterSend: @Sendable (NativeNearbyState) async -> Void
    var notifyCancelled: @Sendable (UUID) -> Void
    var retire: @Sendable () -> Void
    var nowMillis: @Sendable () -> Int64

    @MainActor init(
        access: NativeNearbyAccess,
        relay: CancellationRelay,
        nowMillis: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
    ) {
        // Runtime assertion of pinned TCA Store's MainActor contract; Reducer is synchronous.
        initialState = { try MainActor.assumeIsolated { try access.initial() } }
        preciseLocationResolvedState = { state, lat, lon in try MainActor.assumeIsolated { try access.available(
            state,
            NativeCoordinate(latitude: lat, longitude: lon),
        ) } }
        locationBlockedState = { state, reason in try MainActor.assumeIsolated { try access.blocked(
            state,
            reason.nativeReason,
        ) } }
        locationTemporarilyUnavailableState = { state in try MainActor.assumeIsolated { try access.temporary(state) } }
        loadingState = { state in try MainActor.assumeIsolated { try access.loading(state) } }
        refresh = { state, now in try await access.refresh(state, now: now) }
        shouldRefresh = { state, now in try MainActor.assumeIsolated { try access.shouldRefresh(state, now: now) } }
        timePassed = { state, now in try MainActor.assumeIsolated { try access.timePassed(state, now: now) } }
        adopt = { state in try MainActor.assumeIsolated { try access.adoptResult(state) } }
        release = { state in MainActor.assumeIsolated { access.releaseOwned(state) } }
        discard = { state in MainActor.assumeIsolated { access.discardUnclaimed(state) } }
        discardAfterSend = { state in await access.discardUnclaimed(state) }
        notifyCancelled = { request in _ = Task.detached { @MainActor in relay.deliver(request) } }
        retire = { MainActor.assumeIsolated { access.retire() } }
        self.nowMillis = nowMillis
    }

    private init() {
        initialState = { fatalError("Composition root must inject Nearby client") }
        preciseLocationResolvedState = { _, _, _ in fatalError("Composition root must inject Nearby client") }
        locationBlockedState = { _, _ in fatalError("Composition root must inject Nearby client") }
        locationTemporarilyUnavailableState = { _ in fatalError("Composition root must inject Nearby client") }
        loadingState = { _ in fatalError("Composition root must inject Nearby client") }
        refresh = { _, _ in fatalError("Composition root must inject Nearby client") }
        shouldRefresh = { _, _ in fatalError("Composition root must inject Nearby client") }
        timePassed = { _, _ in fatalError("Composition root must inject Nearby client") }
        adopt = { _ in fatalError("Composition root must inject Nearby client") }
        release = { _ in fatalError("Composition root must inject Nearby client") }
        discard = { _ in fatalError("Composition root must inject Nearby client") }
        discardAfterSend = { _ in fatalError("Composition root must inject Nearby client") }
        notifyCancelled = { _ in fatalError("Composition root must inject cancellation relay") }
        retire = { fatalError("Composition root must inject Nearby client") }
        nowMillis = { Int64(Date().timeIntervalSince1970 * 1000) }
    }
}

extension NearbyVehicleMapFeatureClient: DependencyKey { static let liveValue = NearbyVehicleMapFeatureClient() }
extension DependencyValues {
    var nearbyVehicleMapFeatureClient: NearbyVehicleMapFeatureClient {
        get { self[NearbyVehicleMapFeatureClient.self] }
        set { self[NearbyVehicleMapFeatureClient.self] = newValue }
    }
}

private extension NearbyVehicleMapFeature.LocationBlockedReason {
    var nativeReason: NativeLocationBlocked {
        switch self {
        case .accessDenied: .accessDenied
        case .accessRestricted: .accessRestricted
        case .servicesDisabled: .servicesDisabled
        case .approximateOnly: .approximateOnly
        case .temporarilyUnavailable: .temporarilyUnavailable
        }
    }
}
