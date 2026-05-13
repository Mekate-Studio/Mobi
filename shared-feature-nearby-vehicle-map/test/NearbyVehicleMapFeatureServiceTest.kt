package studio.mekate.mobi.feature.nearbyvehiclemap

import kotlinx.coroutines.test.runTest
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRepositoryException
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.core.VehicleId
import studio.mekate.mobi.core.VehicleLocation
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

class NearbyVehicleMapFeatureServiceTest {
    @Test
    fun `should start with resolving rider location and initial snapshot state`() {
        // given
        val service = createService()

        // when
        val state = service.initialState()

        // then
        assertIs<RiderLocationState.Resolving>(state.riderLocationState)
        assertIs<NearbyVehicleSnapshotState.Initial>(state.snapshotState)
        assertIs<NearbyVehicleMapOverlayState.None>(state.mapOverlayState)
    }

    @Test
    fun `should load initial snapshot when rider location is available`() =
        runTest {
            // given
            val riderLocation = defaultRiderLocation()
            val service = createService()
            val state =
                service.riderLocationAvailable(
                    currentState = service.initialState(),
                    location = riderLocation,
                )

            // when
            val loadedState = service.refreshSnapshot(currentState = state, nowMillis = 1_000)

            // then
            val loaded = assertIs<NearbyVehicleSnapshotState.Loaded>(loadedState.snapshotState)
            assertEquals(riderLocation, loaded.snapshot.riderLocation)
            assertEquals(1_000, loaded.snapshot.loadedAtMillis)
            assertIs<NearbyVehicleMapOverlayState.None>(loadedState.mapOverlayState)
        }

    @Test
    fun `should keep previous snapshot visible while refresh is in progress`() {
        // given
        val service = createService()
        val loadedState =
            loadedState(
                service = service,
                snapshot = snapshot(loadedAtMillis = 1_000),
            )

        // when
        val refreshingState = service.loadingState(loadedState)

        // then
        val refreshing = assertIs<NearbyVehicleSnapshotState.Refreshing>(refreshingState.snapshotState)
        assertEquals(snapshot(loadedAtMillis = 1_000), refreshing.snapshot)
        assertIs<NearbyVehicleMapOverlayState.RefreshingIndicator>(refreshingState.mapOverlayState)
    }

    @Test
    fun `should request refresh after ten seconds since last successful snapshot`() {
        // given
        val service = createService()
        val state =
            loadedState(
                service = service,
                snapshot = snapshot(loadedAtMillis = 1_000),
            )

        // when
        val shouldRefreshBeforeInterval = service.shouldRefresh(currentState = state, nowMillis = 10_999)
        val shouldRefreshAtInterval = service.shouldRefresh(currentState = state, nowMillis = 11_000)

        // then
        assertFalse(shouldRefreshBeforeInterval)
        assertTrue(shouldRefreshAtInterval)
    }

    @Test
    fun `should keep stale snapshot visible when refresh fails inside stale window`() =
        runTest {
            // given
            val service = createService(shouldFail = true)
            val state =
                loadedState(
                    service = service,
                    snapshot = snapshot(loadedAtMillis = 1_000),
                )

            // when
            val failedState = service.refreshSnapshot(currentState = state, nowMillis = 30_000)

            // then
            val failed = assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(failedState.snapshotState)
            assertEquals(snapshot(loadedAtMillis = 1_000), failed.snapshot)
            assertEquals(NearbyVehicleMapFailureReason.RepositoryUnavailable, failed.reason)
            assertIs<NearbyVehicleMapOverlayState.StaleIndicator>(failedState.mapOverlayState)
        }

    @Test
    fun `should block the map when failed snapshot exceeds stale window`() =
        runTest {
            // given
            val service = createService(shouldFail = true)
            val state =
                loadedState(
                    service = service,
                    snapshot = snapshot(loadedAtMillis = 1_000),
                )

            // when
            val failedState = service.refreshSnapshot(currentState = state, nowMillis = 31_001)

            // then
            assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(failedState.snapshotState)
            assertIs<NearbyVehicleMapOverlayState.BlockingFailure>(failedState.mapOverlayState)
        }

    @Test
    fun `should block the map when initial snapshot fails before any successful load`() =
        runTest {
            // given
            val service = createService(shouldFail = true)
            val state =
                service.riderLocationAvailable(
                    currentState = service.initialState(),
                    location = defaultRiderLocation(),
                )

            // when
            val failedState = service.refreshSnapshot(currentState = state, nowMillis = 1_000)

            // then
            val failed = assertIs<NearbyVehicleSnapshotState.FailedWithoutSnapshot>(failedState.snapshotState)
            assertEquals(NearbyVehicleMapFailureReason.RepositoryUnavailable, failed.reason)
            assertIs<NearbyVehicleMapOverlayState.BlockingFailure>(failedState.mapOverlayState)
        }

    @Test
    fun `should keep last resolved rider location when live location temporarily degrades`() {
        // given
        val service = createService()
        val riderLocation = defaultRiderLocation()
        val resolvedState =
            service.riderLocationAvailable(
                currentState = service.initialState(),
                location = riderLocation,
            )

        // when
        val degradedState = service.riderLocationTemporarilyUnavailable(resolvedState)

        // then
        val locationState = assertIs<RiderLocationState.TemporarilyUnavailable>(degradedState.riderLocationState)
        assertEquals(riderLocation, locationState.location)
    }

    private fun createService(shouldFail: Boolean = false): NearbyVehicleMapFeatureService =
        NearbyVehicleMapFeatureService(
            nearbyFleetRepository =
                object : NearbyFleetRepository {
                    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
                        if (shouldFail) {
                            throw NearbyFleetRepositoryException()
                        }
                        return snapshot(
                            riderLocation = request.riderLocation,
                            loadedAtMillis = request.requestedAtMillis,
                        )
                    }
                },
            freshnessPolicy = NearbyVehicleMapFreshnessPolicy(),
        )

    private fun loadedState(
        service: NearbyVehicleMapFeatureService,
        snapshot: FleetSnapshot,
    ): NearbyVehicleMapFeatureState =
        service
            .riderLocationAvailable(
                currentState = service.initialState(),
                location = snapshot.riderLocation,
            ).copy(
                snapshotState = NearbyVehicleSnapshotState.Loaded(snapshot = snapshot),
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
                        id = VehicleId("mobi-001"),
                        location = VehicleLocation(latitude = 55.6763, longitude = 12.5681),
                    ),
                ),
            loadedAtMillis = loadedAtMillis,
        )

    private fun defaultRiderLocation(): RiderLocation = RiderLocation(latitude = 55.6761, longitude = 12.5683)
}
