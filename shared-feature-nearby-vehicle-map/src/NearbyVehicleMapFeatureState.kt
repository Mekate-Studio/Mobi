package studio.mekate.mobi.feature.nearbyvehiclemap

import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.RiderLocation

data class NearbyVehicleMapFeatureState(
    val riderLocationState: RiderLocationState,
    val snapshotState: NearbyVehicleSnapshotState,
    val mapOverlayState: NearbyVehicleMapOverlayState,
)

sealed interface RiderLocationState {
    data object Resolving : RiderLocationState

    data class Available(
        override val location: RiderLocation,
    ) : RiderLocationState,
        VisibleRiderLocationState

    data object Denied : RiderLocationState

    data class Blocked(
        val reason: RiderLocationBlockedReason,
    ) : RiderLocationState

    data class TemporarilyUnavailable(
        override val location: RiderLocation,
    ) : RiderLocationState,
        VisibleRiderLocationState

    data object Unavailable : RiderLocationState
}

enum class RiderLocationBlockedReason {
    AccessDenied,
    AccessRestricted,
    ServicesDisabled,
    ApproximateOnly,
    TemporarilyUnavailable,
}

interface VisibleRiderLocationState {
    val location: RiderLocation
}

sealed interface NearbyVehicleSnapshotState {
    data object Initial : NearbyVehicleSnapshotState

    data object Loading : NearbyVehicleSnapshotState

    data class Loaded(
        override val snapshot: FleetSnapshot,
    ) : NearbyVehicleSnapshotState,
        SnapshotBackedNearbyVehicleState

    data class Refreshing(
        override val snapshot: FleetSnapshot,
    ) : NearbyVehicleSnapshotState,
        SnapshotBackedNearbyVehicleState

    data class FailedWithSnapshot(
        override val snapshot: FleetSnapshot,
        override val reason: NearbyVehicleMapFailureReason,
    ) : NearbyVehicleSnapshotState,
        FailedNearbyVehicleSnapshotState,
        SnapshotBackedNearbyVehicleState

    data class FailedWithoutSnapshot(
        override val reason: NearbyVehicleMapFailureReason,
    ) : NearbyVehicleSnapshotState,
        FailedNearbyVehicleSnapshotState
}

sealed interface SnapshotBackedNearbyVehicleState {
    val snapshot: FleetSnapshot
}

sealed interface FailedNearbyVehicleSnapshotState {
    val reason: NearbyVehicleMapFailureReason
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
    riderLocationState is VisibleRiderLocationState &&
        !snapshotState.isRefreshInFlight()

fun NearbyVehicleMapFeatureState.canInteractWithVehicles(): Boolean =
    riderLocationState is VisibleRiderLocationState &&
        mapOverlayState != NearbyVehicleMapOverlayState.BlockingFailure

fun NearbyVehicleSnapshotState.failedWith(reason: NearbyVehicleMapFailureReason): NearbyVehicleSnapshotState =
    when (this) {
        is SnapshotBackedNearbyVehicleState -> {
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
