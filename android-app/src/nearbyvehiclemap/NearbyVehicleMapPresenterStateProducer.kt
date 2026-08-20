package studio.mekate.mobi.nearbyvehiclemap

import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason

class NearbyVehicleMapPresenterStateProducer(
    private val service: NearbyVehicleMapFeatureService,
) {
    fun initialState(): NearbyVehicleMapFeatureState = service.initialState()

    fun preciseLocationResolvedState(
        currentState: NearbyVehicleMapFeatureState,
        location: RiderLocation,
    ): NearbyVehicleMapFeatureState =
        service.riderLocationAvailable(
            currentState = currentState,
            location = location,
        )

    fun locationAccessBlockedState(
        currentState: NearbyVehicleMapFeatureState,
        reason: RiderLocationBlockedReason,
    ): NearbyVehicleMapFeatureState =
        service.riderLocationBlocked(
            currentState = currentState,
            reason = reason,
        )

    fun locationTemporarilyUnavailableState(currentState: NearbyVehicleMapFeatureState): NearbyVehicleMapFeatureState =
        service.riderLocationTemporarilyUnavailable(currentState = currentState)

    fun loadingState(currentState: NearbyVehicleMapFeatureState): NearbyVehicleMapFeatureState =
        service.loadingState(currentState = currentState)

    suspend fun refreshedState(
        currentState: NearbyVehicleMapFeatureState,
        nowMillis: Long,
    ): NearbyVehicleMapFeatureState =
        service.refreshSnapshot(
            currentState = currentState,
            nowMillis = nowMillis,
        )

    fun shouldRefresh(
        currentState: NearbyVehicleMapFeatureState,
        nowMillis: Long,
    ): Boolean =
        service.shouldRefresh(
            currentState = currentState,
            nowMillis = nowMillis,
        )

    fun create(
        featureState: NearbyVehicleMapFeatureState,
        onPreciseLocationResolved: (RiderLocation) -> Unit,
        onLocationAccessBlocked: (RiderLocationBlockedReason) -> Unit,
        onLocationTemporarilyUnavailable: () -> Unit,
        onRefreshRequested: (Long) -> Unit,
    ): NearbyVehicleMapScreenState =
        NearbyVehicleMapScreenState(
            featureState = featureState,
            eventSink = { event ->
                when (event) {
                    is NearbyVehicleMapScreenEvent.PreciseLocationResolved -> {
                        onPreciseLocationResolved(event.location)
                    }

                    is NearbyVehicleMapScreenEvent.LocationAccessBlocked -> {
                        onLocationAccessBlocked(event.reason)
                    }

                    NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable -> {
                        onLocationTemporarilyUnavailable()
                    }

                    is NearbyVehicleMapScreenEvent.VisibleRefreshDue -> {
                        onRefreshRequested(event.nowMillis)
                    }

                    is NearbyVehicleMapScreenEvent.ManualRefreshRequested -> {
                        onRefreshRequested(event.nowMillis)
                    }
                }
            },
        )
}
