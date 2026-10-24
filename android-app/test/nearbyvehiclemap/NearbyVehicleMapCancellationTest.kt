package studio.mekate.mobi.nearbyvehiclemap

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.job
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.core.NearbyFleetRepositoryException
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.FailedNearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFailureReason
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import app.cash.turbine.test as testFlow

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class NearbyVehicleMapCancellationTest {
    @Test
    fun `should recover repository cancellation with current location and snapshot and allow retry`() =
        runTest {
            for (hasSnapshot in listOf(false, true)) {
                for (degraded in listOf(false, true)) {
                    for (previousFailure in listOf(
                        null,
                        NearbyFleetRepositoryException(),
                        IllegalStateException("Unexpected failure"),
                    )) {
                        val repository = ControlledFleetRepository()
                        queuedPresenter(repository).testFlow {
                            // given
                            var loading = startRefresh(repository, hasSnapshot)
                            var request = repository.requests.receive()
                            if (previousFailure != null) {
                                request.complete(Result.failure(previousFailure))
                                awaitItem().eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                                loading = awaitItem()
                                request = repository.requests.receive()
                            }
                            if (degraded) {
                                loading.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                                awaitItem()
                            }
                            val job = repository.jobs.last()

                            // when
                            request.complete(Result.failure(CancellationException()))
                            val recovered = awaitItem()
                            job.join()

                            // then
                            assertTrue(job.isCancelled, "Recovery must rethrow cancellation")
                            assertTrue(recovered.featureState.canRequestRefresh())
                            assertEquals(NearbyVehicleMapOverlayState.None, recovered.featureState.mapOverlayState)
                            val expectedSnapshot =
                                if (hasSnapshot) {
                                    NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 1))
                                } else {
                                    NearbyVehicleSnapshotState.Initial
                                }
                            assertEquals(expectedSnapshot, recovered.featureState.snapshotState)
                            val expectedLocation =
                                if (degraded) {
                                    RiderLocationState.TemporarilyUnavailable(RIDER_LOCATION)
                                } else {
                                    RiderLocationState.Available(RIDER_LOCATION)
                                }
                            assertEquals(expectedLocation, recovered.featureState.riderLocationState)
                            recovered.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 1))
                            awaitItem()
                            repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                            val retried = awaitItem().featureState
                            assertEquals(
                                NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2)),
                                retried.snapshotState,
                            )
                            assertEquals(expectedLocation, retried.riderLocationState)
                            assertTrue(repository.requests.tryReceive().isFailure)
                            cancelAndIgnoreRemainingEvents()
                        }
                    }
                }
            }
        }

    @Test
    fun `should preserve blocked location when an active request is cancelled`() =
        runTest {
            for (hasSnapshot in listOf(false, true)) {
                for (reason in RiderLocationBlockedReason.entries) {
                    val repository = ControlledFleetRepository()
                    queuedPresenter(repository).testFlow {
                        // given
                        val loading = startRefresh(repository, hasSnapshot)
                        val request = repository.requests.receive()
                        loading.eventSink(NearbyVehicleMapScreenEvent.LocationAccessBlocked(reason))
                        val blocked = awaitItem().featureState

                        // when
                        request.complete(Result.failure(CancellationException()))
                        runCurrent()

                        // then
                        assertEquals(NearbyVehicleMapOverlayState.BlockingFailure, blocked.mapOverlayState)
                        assertEquals(
                            NearbyVehicleMapFailureReason.RiderLocationUnavailable,
                            assertIs<FailedNearbyVehicleSnapshotState>(blocked.snapshotState).reason,
                        )
                        assertFalse(blocked.canRequestRefresh())
                        expectNoEvents()
                        cancelAndIgnoreRemainingEvents()
                    }
                }
            }
        }

    @Test
    fun `should not recover an obsolete cancellation while its replacement is loading`() =
        runTest {
            for (location in listOf(RIDER_LOCATION, RiderLocation(latitude = 55.68, longitude = 12.57))) {
                val repository = LateCompletingFleetRepository()
                queuedPresenter(repository).testFlow {
                    try {
                        // given
                        awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                        val loading = awaitItem()
                        val older = repository.requests.receive()
                        loading.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(location))
                        runCurrent()
                        val newer = repository.requests.receive()
                        if (location != RIDER_LOCATION) awaitItem()

                        // when
                        older.complete(Result.failure(CancellationException()))
                        runCurrent()

                        // then
                        expectNoEvents()
                        newer.complete(Result.success(snapshot(sequence = 2, location = location)))
                        val completed = awaitItem().featureState
                        assertEquals(
                            NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2, location = location)),
                            completed.snapshotState,
                        )
                        assertEquals(RiderLocationState.Available(location), completed.riderLocationState)
                        assertTrue(repository.requests.tryReceive().isFailure)
                        cancelAndIgnoreRemainingEvents()
                    } finally {
                        repository.completePendingRequests()
                    }
                }
            }
        }

    @Test
    fun `should retain the timer after an automatic request cancels`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            queuedPresenter(repository).testFlow {
                resolveLocation(repository)
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                val automatic = repository.requests.receive()
                val job = repository.jobs.last()

                // when
                automatic.complete(Result.failure(CancellationException()))
                val recovered = awaitItem().featureState
                job.join()

                // then
                assertTrue(job.isCancelled)
                assertEquals(NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 1)), recovered.snapshotState)
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                assertEquals(
                    NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2)),
                    awaitItem().featureState.snapshotState,
                )
                cancelAndIgnoreRemainingEvents()
            }
        }
}
