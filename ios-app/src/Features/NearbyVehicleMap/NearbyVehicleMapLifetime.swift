import MobiIOSDependencies

@MainActor
struct NearbyVehicleMapLifetime {
    private var task: StoreTask?

    @discardableResult
    mutating func start(in store: StoreOf<NearbyVehicleMapFeature>) -> StoreTask {
        task?.cancel()
        let next = store.send(.task)
        task = next
        return next
    }

    @discardableResult
    mutating func send(
        _ action: NearbyVehicleMapFeature.Action,
        in store: StoreOf<NearbyVehicleMapFeature>,
    ) -> StoreTask? {
        guard task != nil else { return nil }
        let next = store.send(action)
        if !next.isCancelled {
            task = next
        }
        return next
    }

    @discardableResult
    mutating func stop(in store: StoreOf<NearbyVehicleMapFeature>) -> StoreTask {
        task?.cancel()
        task = nil
        return store.send(.suspend)
    }
}
