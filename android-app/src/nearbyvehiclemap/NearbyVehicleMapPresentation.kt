package studio.mekate.mobi.nearbyvehiclemap

import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.core.VehicleLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.SnapshotBackedNearbyVehicleState
import studio.mekate.mobi.feature.nearbyvehiclemap.VisibleRiderLocationState
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
        val scene: NearbyVehicleMapScenePresentation,
    ) : NearbyVehicleMapContentPresentation
}

data class NearbyVehicleMapScenePresentation(
    val camera: NearbyVehicleMapCameraPresentation,
    val riderMarker: NearbyVehicleMapRiderMarkerPresentation,
    val vehicleMarkers: List<NearbyVehicleMapVehicleMarkerPresentation>,
)

data class NearbyVehicleMapCameraPresentation(
    val target: NearbyVehicleMapCoordinatePresentation,
    val zoom: Double,
)

data class NearbyVehicleMapCoordinatePresentation(
    val latitude: Double,
    val longitude: Double,
)

data class NearbyVehicleMapRiderMarkerPresentation(
    val coordinate: NearbyVehicleMapCoordinatePresentation,
)

data class NearbyVehicleMapVehicleMarkerPresentation(
    val id: String,
    val coordinate: NearbyVehicleMapCoordinatePresentation,
)

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
    val snapshotState = snapshotState as? SnapshotBackedNearbyVehicleState
    val riderLocationState = riderLocationState as? VisibleRiderLocationState

    return NearbyVehicleMapPresentation(
        title = "Nearby vehicles",
        message = this.riderLocationState.messageText(snapshotState = snapshotState),
        mapContent =
            if (riderLocationState == null) {
                NearbyVehicleMapContentPresentation.WaitingForRider
            } else {
                NearbyVehicleMapContentPresentation.RiderCentered(
                    scene =
                        riderLocationState.location.toMapScenePresentation(
                            vehicles = snapshotState?.snapshot?.vehicles.orEmpty(),
                        ),
                )
            },
        overlay = mapOverlayState.toPresentation(),
        primaryActionLabel = "Refresh nearby vehicles",
        canRequestRefresh = canRequestRefresh(),
    )
}

private fun RiderLocation.toMapScenePresentation(vehicles: List<NearbyVehicle>): NearbyVehicleMapScenePresentation {
    val riderCoordinate = toMapCoordinatePresentation()
    return NearbyVehicleMapScenePresentation(
        camera =
            NearbyVehicleMapCameraPresentation(
                target = riderCoordinate,
                zoom = RIDER_CENTERED_CAMERA_ZOOM,
            ),
        riderMarker = NearbyVehicleMapRiderMarkerPresentation(coordinate = riderCoordinate),
        vehicleMarkers =
            vehicles.map { vehicle ->
                NearbyVehicleMapVehicleMarkerPresentation(
                    id = vehicle.id.value,
                    coordinate = vehicle.location.toMapCoordinatePresentation(),
                )
            },
    )
}

private fun RiderLocation.toMapCoordinatePresentation(): NearbyVehicleMapCoordinatePresentation =
    NearbyVehicleMapCoordinatePresentation(
        latitude = latitude,
        longitude = longitude,
    )

private fun VehicleLocation.toMapCoordinatePresentation(): NearbyVehicleMapCoordinatePresentation =
    NearbyVehicleMapCoordinatePresentation(
        latitude = latitude,
        longitude = longitude,
    )

private fun RiderLocationState.messageText(snapshotState: SnapshotBackedNearbyVehicleState?): String =
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

private const val RIDER_CENTERED_CAMERA_ZOOM = 15.0

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
