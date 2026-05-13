package studio.mekate.mobi.feature.nearbyvehiclemap

import dev.zacsweers.metro.Inject

@Inject
class NearbyVehicleMapFreshnessPolicy {
    fun shouldRefresh(
        snapshotState: NearbyVehicleSnapshotState,
        nowMillis: Long,
    ): Boolean =
        snapshotState is NearbyVehicleSnapshotState.WithSnapshot &&
            nowMillis - snapshotState.snapshot.loadedAtMillis >= REFRESH_INTERVAL_MILLIS

    fun overlayAfterTimePasses(
        snapshotState: NearbyVehicleSnapshotState,
        nowMillis: Long,
    ): NearbyVehicleMapOverlayState? =
        when (snapshotState) {
            is NearbyVehicleSnapshotState.FailedWithSnapshot -> {
                failureOverlay(snapshotState = snapshotState, nowMillis = nowMillis)
            }

            NearbyVehicleSnapshotState.Initial,
            NearbyVehicleSnapshotState.Loading,
            is NearbyVehicleSnapshotState.Loaded,
            is NearbyVehicleSnapshotState.Refreshing,
            is NearbyVehicleSnapshotState.FailedWithoutSnapshot,
            -> {
                null
            }
        }

    fun failureOverlay(
        snapshotState: NearbyVehicleSnapshotState.Failed,
        nowMillis: Long,
    ): NearbyVehicleMapOverlayState =
        when (snapshotState) {
            is NearbyVehicleSnapshotState.FailedWithoutSnapshot -> {
                NearbyVehicleMapOverlayState.BlockingFailure
            }

            is NearbyVehicleSnapshotState.FailedWithSnapshot -> {
                if (snapshotState.isStaleWindowExceeded(nowMillis = nowMillis)) {
                    NearbyVehicleMapOverlayState.BlockingFailure
                } else {
                    NearbyVehicleMapOverlayState.StaleIndicator
                }
            }
        }

    private fun NearbyVehicleSnapshotState.WithSnapshot.isStaleWindowExceeded(nowMillis: Long): Boolean =
        nowMillis - snapshot.loadedAtMillis > STALE_WINDOW_MILLIS

    companion object {
        const val REFRESH_INTERVAL_MILLIS: Long = 10_000
        const val STALE_WINDOW_MILLIS: Long = 30_000
    }
}
