package studio.mekate.mobi.nearbyvehiclemap

import com.slack.circuit.test.CircuitReceiveTurbine
import com.slack.circuit.test.test
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFreshnessPolicy
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class NearbyVehicleMapPresenterTest {
    @Test
    fun `should let an automatic refresh finish across loading recomposition`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            val presenter = presenter(repository)
            presenter.test {
                resolveLocation(repository)

                // when
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                val automatic = repository.requests.receive()
                runCurrent()
                assertFalse(automatic.isCancelled, "Loading recomposition must preserve the automatic request")
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 2)
                runCurrent()
                assertFalse(automatic.isCancelled)
                assertTrue(repository.requests.tryReceive().isFailure)
                automatic.complete(snapshot(sequence = 2))

                // then
                val completed = assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                assertEquals(2L, completed.snapshot.sequence)
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                repository.requests.receive().complete(snapshot(sequence = 3))
                assertEquals(
                    3L,
                    assertIs<NearbyVehicleSnapshotState.Loaded>(
                        awaitItem().featureState.snapshotState,
                    ).snapshot.sequence,
                )
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should leave a manual refresh alone across automatic timer ticks`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            presenter(repository).test {
                val loaded = resolveLocation(repository)
                loaded.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                val manual = repository.requests.receive()

                // when
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                runCurrent()

                // then
                assertFalse(manual.isCancelled)
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                manual.complete(snapshot(sequence = 2))
                assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should preserve blocked location state across automatic timer ticks`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            presenter(repository).test {
                resolveLocation(repository).eventSink(
                    NearbyVehicleMapScreenEvent.LocationAccessBlocked(RiderLocationBlockedReason.AccessDenied),
                )
                val blocked = awaitItem().featureState
                assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(blocked.snapshotState)
                assertEquals(NearbyVehicleMapOverlayState.BlockingFailure, blocked.mapOverlayState)

                // when
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                runCurrent()

                // then
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should leave a snapshot alone while shared freshness policy says it is not due`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            presenter(repository).test {
                // A future timestamp stays not due independently of wall-clock test execution time.
                resolveLocation(repository, loadedAtMillis = Long.MAX_VALUE)

                // when
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                runCurrent()

                // then
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should cancel automatic work when the presenter leaves composition`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            lateinit var automatic: CompletableDeferred<FleetSnapshot>
            presenter(repository).test {
                resolveLocation(repository)
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                automatic = repository.requests.receive()
                assertFalse(automatic.isCancelled)

                // when
                cancelAndIgnoreRemainingEvents()
            }
            runCurrent()

            // then
            assertTrue(automatic.isCancelled)
            advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
            runCurrent()
            assertTrue(repository.requests.tryReceive().isFailure)
        }

    private suspend fun CircuitReceiveTurbine<NearbyVehicleMapScreenState>.resolveLocation(
        repository: ControlledFleetRepository,
        loadedAtMillis: Long = 0,
    ): NearbyVehicleMapScreenState {
        awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
        assertIs<NearbyVehicleSnapshotState.Loading>(awaitItem().featureState.snapshotState)
        repository.requests.receive().complete(snapshot(sequence = 1, loadedAtMillis = loadedAtMillis))
        return awaitItem().also { assertIs<NearbyVehicleSnapshotState.Loaded>(it.featureState.snapshotState) }
    }

    private fun presenter(repository: NearbyFleetRepository) =
        NearbyVehicleMapPresenter(
            NearbyVehicleMapFeatureService(repository, NearbyVehicleMapFreshnessPolicy()),
        )

    private fun snapshot(
        sequence: Long,
        loadedAtMillis: Long = 0,
    ) = FleetSnapshot(
        sequence = sequence,
        riderLocation = RIDER_LOCATION,
        vehicles = emptyList(),
        loadedAtMillis = loadedAtMillis,
    )

    private companion object {
        val RIDER_LOCATION = RiderLocation(latitude = 55.6761, longitude = 12.5683)
        const val REFRESH_INTERVAL_MILLIS = NearbyVehicleMapFeatureService.REFRESH_INTERVAL_MILLIS
    }
}

private class ControlledFleetRepository : NearbyFleetRepository {
    val requests = Channel<CompletableDeferred<FleetSnapshot>>(Channel.UNLIMITED)

    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
        val result = CompletableDeferred<FleetSnapshot>(currentCoroutineContext()[Job])
        requests.send(result)
        return result.await()
    }
}
