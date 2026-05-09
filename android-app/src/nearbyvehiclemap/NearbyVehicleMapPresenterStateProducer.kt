package studio.mekate.mobi.nearbyvehiclemap

import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState

class NearbyVehicleMapPresenterStateProducer(
    private val service: NearbyVehicleMapFeatureService,
) {
    fun initialState(): NearbyVehicleMapFeatureState = service.initialState()

    fun permissionGrantedState(
        currentState: NearbyVehicleMapFeatureState,
        location: RiderLocation = COPENHAGEN_RIDER_LOCATION,
    ): NearbyVehicleMapFeatureState =
        service.riderLocationAvailable(
            currentState = currentState,
            location = location,
        )

    fun permissionDeniedState(currentState: NearbyVehicleMapFeatureState): NearbyVehicleMapFeatureState =
        service.riderLocationDenied(currentState = currentState)

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
        onLocationPermissionGranted: () -> Unit,
        onLocationPermissionDenied: () -> Unit,
        onLocationTemporarilyUnavailable: () -> Unit,
        onRefreshRequested: (Long) -> Unit,
    ): NearbyVehicleMapScreenState =
        NearbyVehicleMapScreenState(
            featureState = featureState,
            eventSink = { event ->
                when (event) {
                    NearbyVehicleMapScreenEvent.LocationPermissionGranted -> onLocationPermissionGranted()
                    NearbyVehicleMapScreenEvent.LocationPermissionDenied -> onLocationPermissionDenied()
                    NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable -> onLocationTemporarilyUnavailable()
                    is NearbyVehicleMapScreenEvent.VisibleRefreshDue -> onRefreshRequested(event.nowMillis)
                    is NearbyVehicleMapScreenEvent.ManualRefreshRequested -> onRefreshRequested(event.nowMillis)
                }
            },
        )

    companion object {
        val COPENHAGEN_RIDER_LOCATION = RiderLocation(latitude = 55.6761, longitude = 12.5683)
    }
}
