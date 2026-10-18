import Foundation

/// Candidate seam for non-Store callers: async entry explicitly hops, then calls
/// the unchanged synchronous client. Production reducer APIs remain untouched.
struct ExecutorHomeClient: Sendable {
    let raw: HomeFeatureClient
    @MainActor func initialSync() throws -> HomeCounterLoadable {
        try raw.initialState()
    }

    func initial() async throws -> HomeCounterLoadable {
        try await MainActor.run { try raw.initialState() }
    }

    func loading(_ current: Int) async throws -> HomeCounterLoadable {
        try await MainActor
            .run { try raw.loadingState(current) }
    }

    func retire() async {
        await MainActor.run { raw.retire() }
    }
}

struct ExecutorNearbyClient: Sendable {
    let raw: NearbyVehicleMapFeatureClient
    @MainActor func initialSync() throws -> NativeNearbyState {
        try raw.initialState()
    }

    func initial() async throws -> NativeNearbyState {
        try await MainActor.run { try raw.initialState() }
    }

    func loading(_ value: NativeNearbyState) async throws -> NativeNearbyState {
        try await MainActor
            .run { try raw.loadingState(value) }
    }

    func release(_ value: NativeNearbyState) async {
        await MainActor.run { raw.release(value) }
    }

    func retire() async {
        await MainActor.run { raw.retire() }
    }
}
