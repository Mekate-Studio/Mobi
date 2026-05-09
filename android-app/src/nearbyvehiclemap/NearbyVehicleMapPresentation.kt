package studio.mekate.mobi.nearbyvehiclemap

import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState

data class NearbyVehicleMapPresentation(
    val title: String,
    val message: String,
    val riderLocation: RiderLocation?,
    val vehicles: List<NearbyVehicle>,
    val overlay: NearbyVehicleMapOverlayPresentation,
    val primaryActionLabel: String,
    val canRequestRefresh: Boolean,
)

data class NearbyVehicleMapOverlayPresentation(
    val headline: String?,
    val message: String?,
    val blocksMap: Boolean,
)

fun NearbyVehicleMapFeatureState.toNearbyVehicleMapPresentation(): NearbyVehicleMapPresentation {
    val snapshot = snapshotState.currentSnapshotOrNull()

    return NearbyVehicleMapPresentation(
        title = "Nearby vehicles",
        message = riderLocationState.messageText(snapshot = snapshot),
        riderLocation = riderLocationState.riderLocationOrNull(),
        vehicles = snapshot?.vehicles.orEmpty(),
        overlay = mapOverlayState.toPresentation(),
        primaryActionLabel = "Refresh nearby vehicles",
        canRequestRefresh =
            riderLocationState.riderLocationOrNull() != null &&
                snapshotState !is NearbyVehicleSnapshotState.Loading &&
                snapshotState !is NearbyVehicleSnapshotState.Refreshing,
    )
}

private fun RiderLocationState.messageText(snapshot: FleetSnapshot?): String =
    when (this) {
        RiderLocationState.Resolving -> {
            "Grant while-in-use location access to center discovery around the rider."
        }

        is RiderLocationState.Available -> {
            if (snapshot == null) {
                "Rider location is ready. Load the first rider-centered fleet snapshot."
            } else {
                "Showing ${snapshot.vehicles.size} vehicles around the rider."
            }
        }

        RiderLocationState.Denied -> {
            "Location access is required before nearby vehicles can be positioned relative to the rider."
        }

        is RiderLocationState.TemporarilyUnavailable -> {
            if (lastResolvedLocation == null) {
                "Rider location is temporarily unavailable, so discovery is blocked."
            } else {
                "Live location is temporarily unavailable. Keeping the last resolved rider position."
            }
        }
    }

private fun RiderLocationState.riderLocationOrNull(): RiderLocation? =
    when (this) {
        is RiderLocationState.Available -> location

        is RiderLocationState.TemporarilyUnavailable -> lastResolvedLocation

        RiderLocationState.Denied,
        RiderLocationState.Resolving,
        -> null
    }

private fun NearbyVehicleSnapshotState.currentSnapshotOrNull(): FleetSnapshot? =
    when (this) {
        is NearbyVehicleSnapshotState.Loaded -> snapshot

        is NearbyVehicleSnapshotState.Refreshing -> snapshot

        is NearbyVehicleSnapshotState.Failed -> previousSnapshot

        NearbyVehicleSnapshotState.Initial,
        NearbyVehicleSnapshotState.Loading,
        -> null
    }

private fun NearbyVehicleMapOverlayState.toPresentation(): NearbyVehicleMapOverlayPresentation =
    when (this) {
        NearbyVehicleMapOverlayState.None -> {
            NearbyVehicleMapOverlayPresentation(
                headline = null,
                message = null,
                blocksMap = false,
            )
        }

        NearbyVehicleMapOverlayState.RefreshingIndicator -> {
            NearbyVehicleMapOverlayPresentation(
                headline = "Refreshing",
                message = "Keeping the last snapshot visible while the simulated fleet updates.",
                blocksMap = false,
            )
        }

        NearbyVehicleMapOverlayState.StaleIndicator -> {
            NearbyVehicleMapOverlayPresentation(
                headline = "Snapshot may be stale",
                message = "The last successful fleet snapshot is still visible inside the freshness window.",
                blocksMap = false,
            )
        }

        NearbyVehicleMapOverlayState.BlockingFailure -> {
            NearbyVehicleMapOverlayPresentation(
                headline = "Map unavailable",
                message = "A trustworthy rider-centered vehicle snapshot is not available right now.",
                blocksMap = true,
            )
        }
    }
