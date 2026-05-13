package studio.mekate.mobi.feature.nearbyvehiclemap

import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.RiderLocation

data class NearbyVehicleMapFeatureState(
    val riderLocationState: RiderLocationState,
    val snapshotState: NearbyVehicleSnapshotState,
    val mapOverlayState: NearbyVehicleMapOverlayState,
)

sealed interface RiderLocationState {
    sealed interface Visible : RiderLocationState {
        val location: RiderLocation
    }

    data object Resolving : RiderLocationState

    data class Available(
        override val location: RiderLocation,
    ) : Visible

    data object Denied : RiderLocationState

    data class TemporarilyUnavailable(
        override val location: RiderLocation,
    ) : Visible

    data object Unavailable : RiderLocationState
}

sealed interface NearbyVehicleSnapshotState {
    sealed interface WithSnapshot : NearbyVehicleSnapshotState {
        val snapshot: FleetSnapshot
    }

    sealed interface Failed : NearbyVehicleSnapshotState {
        val reason: NearbyVehicleMapFailureReason
    }

    data object Initial : NearbyVehicleSnapshotState

    data object Loading : NearbyVehicleSnapshotState

    data class Loaded(
        override val snapshot: FleetSnapshot,
    ) : WithSnapshot

    data class Refreshing(
        override val snapshot: FleetSnapshot,
    ) : WithSnapshot

    data class FailedWithSnapshot(
        override val snapshot: FleetSnapshot,
        override val reason: NearbyVehicleMapFailureReason,
    ) : Failed,
        WithSnapshot

    data class FailedWithoutSnapshot(
        override val reason: NearbyVehicleMapFailureReason,
    ) : Failed
}

enum class NearbyVehicleMapFailureReason {
    RiderLocationUnavailable,
    RepositoryUnavailable,
    Unexpected,
}

sealed interface NearbyVehicleMapOverlayState {
    data object None : NearbyVehicleMapOverlayState

    data object RefreshingIndicator : NearbyVehicleMapOverlayState

    data object StaleIndicator : NearbyVehicleMapOverlayState

    data object BlockingFailure : NearbyVehicleMapOverlayState
}

fun NearbyVehicleMapFeatureState.canRequestRefresh(): Boolean =
    riderLocationState is RiderLocationState.Visible &&
        !snapshotState.isRefreshInFlight()

fun NearbyVehicleSnapshotState.failedWith(reason: NearbyVehicleMapFailureReason): NearbyVehicleSnapshotState.Failed =
    when (this) {
        is NearbyVehicleSnapshotState.WithSnapshot -> {
            NearbyVehicleSnapshotState.FailedWithSnapshot(
                snapshot = snapshot,
                reason = reason,
            )
        }

        NearbyVehicleSnapshotState.Loading,
        NearbyVehicleSnapshotState.Initial,
        is NearbyVehicleSnapshotState.FailedWithoutSnapshot,
        -> {
            NearbyVehicleSnapshotState.FailedWithoutSnapshot(reason = reason)
        }
    }

fun NearbyVehicleSnapshotState.isRefreshInFlight(): Boolean =
    this is NearbyVehicleSnapshotState.Loading ||
        this is NearbyVehicleSnapshotState.Refreshing
