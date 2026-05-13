package studio.mekate.mobi.feature.nearbyvehiclemap

import dev.zacsweers.metro.Inject
import studio.mekate.mobi.core.FleetSnapshot

@Inject
class NearbyVehicleMapFreshnessPolicy {
    fun shouldRefresh(
        snapshotState: NearbyVehicleSnapshotState,
        nowMillis: Long,
    ): Boolean {
        val snapshot = snapshotState.currentSnapshotOrNull() ?: return false
        return nowMillis - snapshot.loadedAtMillis >= REFRESH_INTERVAL_MILLIS
    }

    fun overlayAfterTimePasses(
        snapshotState: NearbyVehicleSnapshotState,
        nowMillis: Long,
    ): NearbyVehicleMapOverlayState? {
        val snapshot = snapshotState.currentSnapshotOrNull()

        return if (snapshot == null || snapshotState !is NearbyVehicleSnapshotState.Failed) {
            null
        } else {
            failureOverlay(previousSnapshot = snapshot, nowMillis = nowMillis)
        }
    }

    fun failureOverlay(
        previousSnapshot: FleetSnapshot?,
        nowMillis: Long,
    ): NearbyVehicleMapOverlayState =
        when {
            previousSnapshot == null -> {
                NearbyVehicleMapOverlayState.BlockingFailure
            }

            isStaleWindowExceeded(snapshot = previousSnapshot, nowMillis = nowMillis) -> {
                NearbyVehicleMapOverlayState.BlockingFailure
            }

            else -> {
                NearbyVehicleMapOverlayState.StaleIndicator
            }
        }

    private fun isStaleWindowExceeded(
        snapshot: FleetSnapshot,
        nowMillis: Long,
    ): Boolean = nowMillis - snapshot.loadedAtMillis > STALE_WINDOW_MILLIS

    companion object {
        const val REFRESH_INTERVAL_MILLIS: Long = 10_000
        const val STALE_WINDOW_MILLIS: Long = 30_000
    }
}
