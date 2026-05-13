package studio.mekate.mobi.nearbyvehiclemap

import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import studio.mekate.mobi.feature.nearbyvehiclemap.currentSnapshotOrNull
import studio.mekate.mobi.feature.nearbyvehiclemap.visibleLocationOrNull

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
    val snapshot = snapshotState.currentSnapshotOrNull()
    val riderLocation = riderLocationState.visibleLocationOrNull()

    return NearbyVehicleMapPresentation(
        title = "Nearby vehicles",
        message = riderLocationState.messageText(snapshot = snapshot),
        mapContent =
            if (riderLocation == null) {
                NearbyVehicleMapContentPresentation.WaitingForRider
            } else {
                NearbyVehicleMapContentPresentation.RiderCentered(
                    riderLocation = riderLocation,
                    vehicles = snapshot?.vehicles.orEmpty(),
                )
            },
        overlay = mapOverlayState.toPresentation(),
        primaryActionLabel = "Refresh nearby vehicles",
        canRequestRefresh = canRequestRefresh(),
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
