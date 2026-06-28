package studio.mekate.mobi.nearbyvehiclemap

import kotlinx.coroutines.test.runTest
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.core.VehicleId
import studio.mekate.mobi.core.VehicleLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFailureReason
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFreshnessPolicy
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

class NearbyVehicleMapPresenterStateProducerTest {
    @Test
    fun `should wire precise location into shared rider location state`() {
        // given
        val producer = createStateProducer()
        val initialState = producer.initialState()

        // when
        val resolvedState =
            producer.preciseLocationResolvedState(
                currentState = initialState,
                location = defaultRiderLocation(),
            )

        // then
        val riderLocation = assertIs<RiderLocationState.Available>(resolvedState.riderLocationState)
        assertEquals(defaultRiderLocation(), riderLocation.location)
    }

    @Test
    fun `should wire blocked location access into blocking overlay state`() {
        // given
        val producer = createStateProducer()
        val initialState = producer.initialState()

        // when
        val blockedState =
            producer.locationAccessBlockedState(
                currentState = initialState,
                reason = RiderLocationBlockedReason.ApproximateOnly,
            )

        // then
        val locationState = assertIs<RiderLocationState.Blocked>(blockedState.riderLocationState)
        assertEquals(RiderLocationBlockedReason.ApproximateOnly, locationState.reason)
        assertIs<NearbyVehicleMapOverlayState.BlockingFailure>(blockedState.mapOverlayState)
    }

    @Test
    fun `should request refresh when visible refresh event is sent`() {
        // given
        val producer = createStateProducer()
        var requestedAtMillis = -1L
        val screenState =
            producer.create(
                featureState = producer.initialState(),
                onPreciseLocationResolved = {},
                onLocationAccessBlocked = {},
                onLocationTemporarilyUnavailable = {},
                onRefreshRequested = { nowMillis ->
                    requestedAtMillis = nowMillis
                },
            )

        // when
        screenState.eventSink(NearbyVehicleMapScreenEvent.VisibleRefreshDue(nowMillis = 11_000))

        // then
        assertEquals(11_000, requestedAtMillis)
    }

    @Test
    fun `should present stale overlay as non blocking degraded map state`() {
        // given
        val featureState =
            createStateProducer()
                .initialState()
                .copy(
                    riderLocationState =
                        RiderLocationState.Available(
                            location = defaultRiderLocation(),
                        ),
                    snapshotState =
                        NearbyVehicleSnapshotState.FailedWithSnapshot(
                            snapshot = snapshot(loadedAtMillis = 1_000),
                            reason = NearbyVehicleMapFailureReason.RepositoryUnavailable,
                        ),
                    mapOverlayState = NearbyVehicleMapOverlayState.StaleIndicator,
                )

        // when
        val presentation = featureState.toNearbyVehicleMapPresentation()

        // then
        val overlay = assertIs<NearbyVehicleMapOverlayPresentation.Banner>(presentation.overlay)
        val mapContent = assertIs<NearbyVehicleMapContentPresentation.RiderCentered>(presentation.mapContent)
        assertEquals("Snapshot may be stale", overlay.headline)
        assertTrue(mapContent.scene.vehicleMarkers.isNotEmpty())
        assertTrue(presentation.canInteractWithVehicles)
    }

    @Test
    fun `should present a rider centered map scene with camera rider marker and vehicle markers`() {
        // given
        val featureState =
            createStateProducer()
                .initialState()
                .copy(
                    riderLocationState =
                        RiderLocationState.Available(
                            location = defaultRiderLocation(),
                        ),
                    snapshotState = NearbyVehicleSnapshotState.Loaded(snapshot = snapshot(loadedAtMillis = 1_000)),
                )

        // when
        val presentation = featureState.toNearbyVehicleMapPresentation()

        // then
        val mapContent = assertIs<NearbyVehicleMapContentPresentation.RiderCentered>(presentation.mapContent)
        val scene = mapContent.scene
        assertEquals(55.6761, scene.camera.target.latitude)
        assertEquals(12.5683, scene.camera.target.longitude)
        assertEquals(15.0, scene.camera.zoom)
        assertEquals(scene.camera.target, scene.riderMarker.coordinate)
        assertEquals("mobi-android-001", scene.vehicleMarkers.single().id)
        assertEquals(
            55.6764,
            scene.vehicleMarkers
                .single()
                .coordinate.latitude,
        )
        assertEquals(
            12.5687,
            scene.vehicleMarkers
                .single()
                .coordinate.longitude,
        )
    }

    @Test
    fun `should present empty vehicle markers when rider exists without a snapshot`() {
        // given
        val featureState =
            createStateProducer()
                .initialState()
                .copy(
                    riderLocationState =
                        RiderLocationState.Available(
                            location = defaultRiderLocation(),
                        ),
                    snapshotState = NearbyVehicleSnapshotState.Initial,
                )

        // when
        val presentation = featureState.toNearbyVehicleMapPresentation()

        // then
        val mapContent = assertIs<NearbyVehicleMapContentPresentation.RiderCentered>(presentation.mapContent)
        assertEquals(emptyList(), mapContent.scene.vehicleMarkers)
    }

    @Test
    fun `should keep map scene provider neutral when blocking overlay is visible`() {
        // given
        val featureState =
            createStateProducer()
                .initialState()
                .copy(
                    riderLocationState = RiderLocationState.Denied,
                    snapshotState =
                        NearbyVehicleSnapshotState.FailedWithoutSnapshot(
                            reason = NearbyVehicleMapFailureReason.RiderLocationUnavailable,
                        ),
                    mapOverlayState = NearbyVehicleMapOverlayState.BlockingFailure,
                )

        // when
        val presentation = featureState.toNearbyVehicleMapPresentation()

        // then
        assertIs<NearbyVehicleMapContentPresentation.WaitingForRider>(presentation.mapContent)
        assertIs<NearbyVehicleMapOverlayPresentation.Blocking>(presentation.overlay)
        assertFalse(presentation.canInteractWithVehicles)
    }

    @Test
    fun `should load a snapshot for Android presenter state`() =
        runTest {
            // given
            val producer = createStateProducer()
            val locationState =
                producer.preciseLocationResolvedState(
                    currentState = producer.initialState(),
                    location = defaultRiderLocation(),
                )

            // when
            val loadedState = producer.refreshedState(currentState = locationState, nowMillis = 1_000)

            // then
            val snapshotState = assertIs<NearbyVehicleSnapshotState.Loaded>(loadedState.snapshotState)
            assertEquals(defaultRiderLocation(), snapshotState.snapshot.riderLocation)
        }

    private fun createStateProducer(): NearbyVehicleMapPresenterStateProducer =
        NearbyVehicleMapPresenterStateProducer(
            service =
                NearbyVehicleMapFeatureService(
                    nearbyFleetRepository =
                        object : NearbyFleetRepository {
                            override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot =
                                snapshot(
                                    riderLocation = request.riderLocation,
                                    loadedAtMillis = request.requestedAtMillis,
                                )
                        },
                    freshnessPolicy = NearbyVehicleMapFreshnessPolicy(),
                ),
        )

    private fun snapshot(
        riderLocation: RiderLocation = defaultRiderLocation(),
        loadedAtMillis: Long,
    ): FleetSnapshot =
        FleetSnapshot(
            sequence = 1,
            riderLocation = riderLocation,
            vehicles =
                listOf(
                    NearbyVehicle(
                        id = VehicleId("mobi-android-001"),
                        location = VehicleLocation(latitude = 55.6764, longitude = 12.5687),
                    ),
                ),
            loadedAtMillis = loadedAtMillis,
        )

    private fun defaultRiderLocation(): RiderLocation = RiderLocation(latitude = 55.6761, longitude = 12.5683)
}
