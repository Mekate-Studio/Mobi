package studio.mekate.mobi.nearbyvehiclemap

import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFailureReason
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class NearbyVehicleMapPresentationTest {
    private val location = RiderLocation(latitude = 55.6761, longitude = 12.5683)
    private val messages =
        mapOf(
            NearbyVehicleMapFailureReason.RiderLocationUnavailable to
                "Precise rider location is required before nearby vehicle actions are available.",
            NearbyVehicleMapFailureReason.RepositoryUnavailable to
                "The fleet repository could not load nearby vehicles. Try refreshing again.",
            NearbyVehicleMapFailureReason.Unexpected to
                "Something went wrong while loading nearby vehicles. Try refreshing again.",
        )

    @Test
    fun `should explain blocking failure before the first snapshot`() {
        messages.forEach { (reason, message) ->
            assertBlockingPresentation(
                snapshotState = NearbyVehicleSnapshotState.FailedWithoutSnapshot(reason),
                reason = reason,
                message = message,
            )
        }
    }

    @Test
    fun `should explain blocking failure with a retained snapshot`() {
        val snapshot =
            FleetSnapshot(sequence = 1, riderLocation = location, vehicles = emptyList(), loadedAtMillis = 1_000)
        messages.forEach { (reason, message) ->
            assertBlockingPresentation(
                snapshotState = NearbyVehicleSnapshotState.FailedWithSnapshot(snapshot, reason),
                reason = reason,
                message = message,
            )
        }
    }

    private fun assertBlockingPresentation(
        snapshotState: NearbyVehicleSnapshotState,
        reason: NearbyVehicleMapFailureReason,
        message: String,
    ) {
        // given
        val hasLocation = reason != NearbyVehicleMapFailureReason.RiderLocationUnavailable
        val state =
            NearbyVehicleMapFeatureState(
                riderLocationState =
                    if (hasLocation) {
                        RiderLocationState.Available(
                            location,
                        )
                    } else {
                        RiderLocationState.Denied
                    },
                snapshotState = snapshotState,
                mapOverlayState = NearbyVehicleMapOverlayState.BlockingFailure,
            )

        // when
        val presentation = state.toNearbyVehicleMapPresentation()

        // then
        assertEquals(NearbyVehicleMapOverlayPresentation.Blocking("Map unavailable", message), presentation.overlay)
        assertEquals(hasLocation, presentation.canRequestRefresh)
        assertFalse(presentation.canInteractWithVehicles)
    }
}
