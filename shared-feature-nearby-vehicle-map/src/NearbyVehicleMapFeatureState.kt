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
        val location: RiderLocation,
    ) : RiderLocationState

    data object Denied : RiderLocationState

    data class TemporarilyUnavailable(
        val lastResolvedLocation: RiderLocation?,
    ) : RiderLocationState
}

sealed interface NearbyVehicleSnapshotState {
    data object Initial : NearbyVehicleSnapshotState

    data object Loading : NearbyVehicleSnapshotState

    data class Loaded(
        val snapshot: FleetSnapshot,
    ) : NearbyVehicleSnapshotState

    data class Refreshing(
        val snapshot: FleetSnapshot,
    ) : NearbyVehicleSnapshotState

    data class Failed(
        val previousSnapshot: FleetSnapshot?,
        val reason: NearbyVehicleMapFailureReason,
    ) : NearbyVehicleSnapshotState
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
    riderLocationState.visibleLocationOrNull() != null &&
        !snapshotState.isRefreshInFlight()

fun RiderLocationState.visibleLocationOrNull(): RiderLocation? =
    when (this) {
        is RiderLocationState.Available -> location

        is RiderLocationState.TemporarilyUnavailable -> lastResolvedLocation

        RiderLocationState.Denied,
        RiderLocationState.Resolving,
        -> null
    }

fun RiderLocationState.discoveryLocationOrNull(): RiderLocation? = visibleLocationOrNull()

fun RiderLocationState.lastResolvedLocationOrNull(): RiderLocation? = visibleLocationOrNull()

fun NearbyVehicleSnapshotState.currentSnapshotOrNull(): FleetSnapshot? =
    when (this) {
        is NearbyVehicleSnapshotState.Loaded -> snapshot

        is NearbyVehicleSnapshotState.Refreshing -> snapshot

        is NearbyVehicleSnapshotState.Failed -> previousSnapshot

        NearbyVehicleSnapshotState.Initial,
        NearbyVehicleSnapshotState.Loading,
        -> null
    }

fun NearbyVehicleSnapshotState.isRefreshInFlight(): Boolean =
    this is NearbyVehicleSnapshotState.Loading ||
        this is NearbyVehicleSnapshotState.Refreshing
