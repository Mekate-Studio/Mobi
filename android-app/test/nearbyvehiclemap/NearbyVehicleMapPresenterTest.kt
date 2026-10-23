package studio.mekate.mobi.nearbyvehiclemap

import app.cash.molecule.RecompositionMode
import app.cash.molecule.moleculeFlow
import app.cash.turbine.ReceiveTurbine
import com.slack.circuit.test.test
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRepositoryException
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.RiderLocation
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
import app.cash.turbine.test as testFlow

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
                automatic.complete(Result.success(snapshot(sequence = 2)))

                // then
                val completed = assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                assertEquals(2L, completed.snapshot.sequence)
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                repository.requests.receive().complete(Result.success(snapshot(sequence = 3)))
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
                manual.complete(Result.success(snapshot(sequence = 2)))
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
            lateinit var automatic: CompletableDeferred<Result<FleetSnapshot>>
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

    @Test
    fun `should admit only one queued refresh and allow another after completion`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            queuedPresenter(repository).testFlow {
                val loaded = resolveLocation(repository)

                // when
                loaded.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                loaded.eventSink(NearbyVehicleMapScreenEvent.VisibleRefreshDue(nowMillis = 0))
                runCurrent()

                // then
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                val request = repository.requests.receive()
                loaded.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                runCurrent()
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                request.complete(Result.success(snapshot(sequence = 2)))
                assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                loaded.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                repository.requests.receive().complete(Result.success(snapshot(sequence = 3)))
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
    fun `should preserve blocked state when a retained callback requests refresh`() =
        runTest {
            for (hasSnapshot in listOf(false, true)) {
                for (reason in RiderLocationBlockedReason.entries) {
                    // given
                    val repository = ControlledFleetRepository()
                    queuedPresenter(repository).testFlow {
                        val current = if (hasSnapshot) resolveLocation(repository) else awaitItem()
                        current.eventSink(NearbyVehicleMapScreenEvent.LocationAccessBlocked(reason))
                        val blocked = awaitItem().featureState

                        // when
                        current.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                        current.eventSink(NearbyVehicleMapScreenEvent.VisibleRefreshDue(nowMillis = 0))
                        runCurrent()

                        // then
                        assertEquals(NearbyVehicleMapOverlayState.BlockingFailure, blocked.mapOverlayState)
                        assertTrue(repository.requests.tryReceive().isFailure)
                        expectNoEvents()
                        cancelAndIgnoreRemainingEvents()
                    }
                }
            }
        }

    @Test
    fun `should recheck location before a queued refresh starts`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            queuedPresenter(repository).testFlow {
                val loaded = resolveLocation(repository)

                // when
                loaded.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                loaded.eventSink(
                    NearbyVehicleMapScreenEvent.LocationAccessBlocked(RiderLocationBlockedReason.AccessDenied),
                )
                runCurrent()

                // then
                val blocked = awaitItem().featureState
                assertEquals(RiderLocationState.Denied, blocked.riderLocationState)
                assertEquals(NearbyVehicleMapOverlayState.BlockingFailure, blocked.mapOverlayState)
                assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(blocked.snapshotState)
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should ignore refresh callbacks while location is resolving`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            queuedPresenter(repository).testFlow {
                val initial = awaitItem()

                // when
                initial.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                initial.eventSink(NearbyVehicleMapScreenEvent.VisibleRefreshDue(nowMillis = 0))
                runCurrent()

                // then
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should allow manual refresh and failure retry without waiting for freshness`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            queuedPresenter(repository).testFlow {
                val loaded = resolveLocation(repository, loadedAtMillis = Long.MAX_VALUE)

                // when
                loaded.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                repository.requests.receive().complete(Result.failure(NearbyFleetRepositoryException()))

                // then
                val failed = awaitItem()
                val failure = assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(failed.featureState.snapshotState)
                assertEquals(NearbyVehicleMapFailureReason.RepositoryUnavailable, failure.reason)
                assertEquals(1L, failure.snapshot.sequence)
                failed.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                assertEquals(
                    2L,
                    assertIs<NearbyVehicleSnapshotState.Loaded>(
                        awaitItem().featureState.snapshotState,
                    ).snapshot.sequence,
                )
                cancelAndIgnoreRemainingEvents()
            }
        }

    private fun TestScope.queuedPresenter(repository: NearbyFleetRepository): Flow<NearbyVehicleMapScreenState> {
        val presenter = presenter(repository)
        // Queue presenter launches so Turbine's eager collector cannot hide admission races.
        return moleculeFlow(RecompositionMode.Immediate) { presenter.present() }
            .flowOn(StandardTestDispatcher(testScheduler))
    }

    private suspend fun ReceiveTurbine<NearbyVehicleMapScreenState>.resolveLocation(
        repository: ControlledFleetRepository,
        loadedAtMillis: Long = 0,
    ): NearbyVehicleMapScreenState {
        awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
        assertIs<NearbyVehicleSnapshotState.Loading>(awaitItem().featureState.snapshotState)
        repository.requests.receive().complete(Result.success(snapshot(sequence = 1, loadedAtMillis = loadedAtMillis)))
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
    val requests = Channel<CompletableDeferred<Result<FleetSnapshot>>>(Channel.UNLIMITED)

    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
        val result = CompletableDeferred<Result<FleetSnapshot>>(currentCoroutineContext()[Job])
        requests.send(result)
        // Throw from the repository; failing the deferred child would cancel its parent job.
        return result.await().getOrThrow()
    }
}
