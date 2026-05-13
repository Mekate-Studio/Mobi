package studio.mekate.mobi.nearbyvehiclemap

import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh

data class NearbyVehicleMapPresentation(
    val title: String,
    val message: String,
    val mapContent: NearbyVehicleMapContentPresentation,
    val overlay: NearbyVehicleMapOverlayPresentation,
    val primaryActionLabel: String,
    val canRequestRefresh: Boolean,
)

sealed interface NearbyVehicleMapContentPresentation {
    data object WaitingForRider : NearbyVehicleMapContentPresentation

    data class RiderCentered(
        val riderLocation: RiderLocation,
        val vehicles: List<NearbyVehicle>,
    ) : NearbyVehicleMapContentPresentation
}

sealed interface NearbyVehicleMapOverlayPresentation {
    data object None : NearbyVehicleMapOverlayPresentation

    data class Banner(
        val headline: String,
        val message: String,
    ) : NearbyVehicleMapOverlayPresentation

    data class Blocking(
        val headline: String,
        val message: String,
    ) : NearbyVehicleMapOverlayPresentation
}

fun NearbyVehicleMapFeatureState.toNearbyVehicleMapPresentation(): NearbyVehicleMapPresentation {
    val snapshotState = snapshotState as? NearbyVehicleSnapshotState.WithSnapshot
    val riderLocationState = riderLocationState as? RiderLocationState.Visible

    return NearbyVehicleMapPresentation(
        title = "Nearby vehicles",
        message = this.riderLocationState.messageText(snapshotState = snapshotState),
        mapContent =
            if (riderLocationState == null) {
                NearbyVehicleMapContentPresentation.WaitingForRider
            } else {
                NearbyVehicleMapContentPresentation.RiderCentered(
                    riderLocation = riderLocationState.location,
                    vehicles = snapshotState?.snapshot?.vehicles.orEmpty(),
                )
            },
        overlay = mapOverlayState.toPresentation(),
        primaryActionLabel = "Refresh nearby vehicles",
        canRequestRefresh = canRequestRefresh(),
    )
}

private fun RiderLocationState.messageText(snapshotState: NearbyVehicleSnapshotState.WithSnapshot?): String =
    when (this) {
        RiderLocationState.Resolving -> {
            "Grant while-in-use location access to center discovery around the rider."
        }

        is RiderLocationState.Available -> {
            if (snapshotState == null) {
                "Rider location is ready. Load the first rider-centered fleet snapshot."
            } else {
                "Showing ${snapshotState.snapshot.vehicles.size} vehicles around the rider."
            }
        }

        RiderLocationState.Denied -> {
            "Location access is required before nearby vehicles can be positioned relative to the rider."
        }

        is RiderLocationState.TemporarilyUnavailable -> {
            "Live location is temporarily unavailable. Keeping the last resolved rider position."
        }

        RiderLocationState.Unavailable -> {
            "Rider location is temporarily unavailable, so discovery is blocked."
        }
    }

private fun NearbyVehicleMapOverlayState.toPresentation(): NearbyVehicleMapOverlayPresentation =
    when (this) {
        NearbyVehicleMapOverlayState.None -> {
            NearbyVehicleMapOverlayPresentation.None
        }

        NearbyVehicleMapOverlayState.RefreshingIndicator -> {
            NearbyVehicleMapOverlayPresentation.Banner(
                headline = "Refreshing",
                message = "Keeping the last snapshot visible while the simulated fleet updates.",
            )
        }

        NearbyVehicleMapOverlayState.StaleIndicator -> {
            NearbyVehicleMapOverlayPresentation.Banner(
                headline = "Snapshot may be stale",
                message = "The last successful fleet snapshot is still visible inside the freshness window.",
            )
        }

        NearbyVehicleMapOverlayState.BlockingFailure -> {
            NearbyVehicleMapOverlayPresentation.Blocking(
                headline = "Map unavailable",
                message = "A trustworthy rider-centered vehicle snapshot is not available right now.",
            )
        }
    }
