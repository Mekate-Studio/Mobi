package studio.mekate.mobi.feature.nearbyvehiclemap

import dev.zacsweers.metro.Inject
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRepositoryException
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.RiderLocation
import kotlin.coroutines.cancellation.CancellationException

@Inject
class NearbyVehicleMapFeatureService(
    private val nearbyFleetRepository: NearbyFleetRepository,
    private val freshnessPolicy: NearbyVehicleMapFreshnessPolicy,
) {
    fun initialState(): NearbyVehicleMapFeatureState =
        NearbyVehicleMapFeatureState(
            riderLocationState = RiderLocationState.Resolving,
            snapshotState = NearbyVehicleSnapshotState.Initial,
            mapOverlayState = NearbyVehicleMapOverlayState.None,
        )

    fun riderLocationAvailable(
        currentState: NearbyVehicleMapFeatureState,
        location: RiderLocation,
    ): NearbyVehicleMapFeatureState =
        currentState.copy(
            riderLocationState = RiderLocationState.Available(location = location),
        )

    fun riderLocationDenied(currentState: NearbyVehicleMapFeatureState): NearbyVehicleMapFeatureState =
        currentState.copy(
            riderLocationState = RiderLocationState.Denied,
            snapshotState =
                currentState.snapshotState.failedWith(
                    reason = NearbyVehicleMapFailureReason.RiderLocationUnavailable,
                ),
            mapOverlayState = NearbyVehicleMapOverlayState.BlockingFailure,
        )

    fun riderLocationTemporarilyUnavailable(currentState: NearbyVehicleMapFeatureState): NearbyVehicleMapFeatureState {
        val riderLocationState =
            when (val currentLocationState = currentState.riderLocationState) {
                is RiderLocationState.Visible -> {
                    RiderLocationState.TemporarilyUnavailable(
                        location = currentLocationState.location,
                    )
                }

                RiderLocationState.Denied,
                RiderLocationState.Resolving,
                RiderLocationState.Unavailable,
                -> {
                    RiderLocationState.Unavailable
                }
            }

        return currentState.copy(
            riderLocationState = riderLocationState,
            mapOverlayState =
                if (
                    riderLocationState !is RiderLocationState.Visible &&
                    currentState.snapshotState !is NearbyVehicleSnapshotState.WithSnapshot
                ) {
                    NearbyVehicleMapOverlayState.BlockingFailure
                } else {
                    currentState.mapOverlayState
                },
        )
    }

    fun loadingState(currentState: NearbyVehicleMapFeatureState): NearbyVehicleMapFeatureState =
        currentState.copy(
            snapshotState =
                when (val snapshotState = currentState.snapshotState) {
                    is NearbyVehicleSnapshotState.WithSnapshot -> {
                        NearbyVehicleSnapshotState.Refreshing(snapshot = snapshotState.snapshot)
                    }

                    NearbyVehicleSnapshotState.Initial,
                    NearbyVehicleSnapshotState.Loading,
                    is NearbyVehicleSnapshotState.FailedWithoutSnapshot,
                    -> {
                        NearbyVehicleSnapshotState.Loading
                    }
                },
            mapOverlayState =
                when (currentState.snapshotState) {
                    is NearbyVehicleSnapshotState.WithSnapshot -> NearbyVehicleMapOverlayState.RefreshingIndicator

                    NearbyVehicleSnapshotState.Initial,
                    NearbyVehicleSnapshotState.Loading,
                    is NearbyVehicleSnapshotState.FailedWithoutSnapshot,
                    -> NearbyVehicleMapOverlayState.None
                },
        )

    @Suppress("SwallowedException", "TooGenericExceptionCaught")
    suspend fun refreshSnapshot(
        currentState: NearbyVehicleMapFeatureState,
        nowMillis: Long,
    ): NearbyVehicleMapFeatureState {
        val riderLocation =
            (currentState.riderLocationState as? RiderLocationState.Visible)?.location
                ?: return failedState(
                    currentState = currentState,
                    reason = NearbyVehicleMapFailureReason.RiderLocationUnavailable,
                    nowMillis = nowMillis,
                )

        return try {
            val snapshot =
                nearbyFleetRepository.fetchNearbyFleetSnapshot(
                    NearbyFleetRequest(
                        riderLocation = riderLocation,
                        requestedAtMillis = nowMillis,
                    ),
                )

            currentState.copy(
                snapshotState = NearbyVehicleSnapshotState.Loaded(snapshot = snapshot),
                mapOverlayState = NearbyVehicleMapOverlayState.None,
            )
        } catch (error: CancellationException) {
            throw error
        } catch (error: NearbyFleetRepositoryException) {
            failedState(
                currentState = currentState,
                reason = NearbyVehicleMapFailureReason.RepositoryUnavailable,
                nowMillis = nowMillis,
            )
        } catch (error: Exception) {
            failedState(
                currentState = currentState,
                reason = NearbyVehicleMapFailureReason.Unexpected,
                nowMillis = nowMillis,
            )
        }
    }

    fun shouldRefresh(
        currentState: NearbyVehicleMapFeatureState,
        nowMillis: Long,
    ): Boolean =
        freshnessPolicy.shouldRefresh(
            snapshotState = currentState.snapshotState,
            nowMillis = nowMillis,
        )

    fun stateAfterTimePasses(
        currentState: NearbyVehicleMapFeatureState,
        nowMillis: Long,
    ): NearbyVehicleMapFeatureState {
        val overlayState =
            freshnessPolicy.overlayAfterTimePasses(
                snapshotState = currentState.snapshotState,
                nowMillis = nowMillis,
            ) ?: return currentState

        return currentState.copy(mapOverlayState = overlayState)
    }

    private fun failedState(
        currentState: NearbyVehicleMapFeatureState,
        reason: NearbyVehicleMapFailureReason,
        nowMillis: Long,
    ): NearbyVehicleMapFeatureState {
        val snapshotState = currentState.snapshotState.failedWith(reason = reason)

        return currentState.copy(
            snapshotState = snapshotState,
            mapOverlayState =
                freshnessPolicy.failureOverlay(
                    snapshotState = snapshotState,
                    nowMillis = nowMillis,
                ),
        )
    }

    companion object {
        const val REFRESH_INTERVAL_MILLIS: Long = NearbyVehicleMapFreshnessPolicy.REFRESH_INTERVAL_MILLIS
        const val STALE_WINDOW_MILLIS: Long = NearbyVehicleMapFreshnessPolicy.STALE_WINDOW_MILLIS
    }
}
