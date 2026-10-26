package studio.mekate.mobi.nearbyvehiclemap

import androidx.lifecycle.Lifecycle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.TabContentOwner
import studio.mekate.mobi.core.NearbyFleetRepositoryException
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import studio.mekate.mobi.feature.nearbyvehiclemap.isRefreshInFlight
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import app.cash.turbine.test as testFlow

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class NearbyForegroundRequestTest {
    @Test
    fun `should cancel pending initial manual and automatic requests synchronously on STOP`() =
        runTest {
            for (kind in listOf("initial", "manual", "automatic")) {
                // given
                val repository = ControlledFleetRepository()
                val owner = TabContentOwner()
                nearbyTabContent(repository, owner = owner).testFlow {
                    if (kind == "initial") {
                        awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                    } else {
                        val loaded = resolveLocation(repository)
                        if (kind == "manual") {
                            loaded.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(0))
                        } else {
                            advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                            runCurrent()
                        }
                    }
                    val loading = awaitItem()
                    val request = repository.requests.receive()

                    // when
                    owner.lifecycle.currentState = Lifecycle.State.STARTED
                    assertFalse(request.isCancelled)
                    owner.lifecycle.currentState = Lifecycle.State.CREATED

                    // then: cleanup must run before recomposition or provider completion.
                    assertTrue(repository.jobs.last().isCancelled)
                    assertTrue(request.isCancelled)
                    val stopped = awaitItem().featureState
                    assertFalse(stopped.snapshotState.isRefreshInFlight())
                    if (kind == "initial") {
                        assertEquals(NearbyVehicleSnapshotState.Initial, stopped.snapshotState)
                    } else {
                        assertEquals(NearbyVehicleSnapshotState.Loaded(snapshot(1)), stopped.snapshotState)
                    }
                    loading.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(0))
                    loading.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                    loading.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                    loading.eventSink(
                        NearbyVehicleMapScreenEvent.LocationAccessBlocked(RiderLocationBlockedReason.AccessDenied),
                    )
                    runCurrent()
                    expectNoEvents()
                    assertTrue(repository.requests.tryReceive().isFailure)
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should reject queued work stopped before admission and allow location retry after START`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner()
            nearbyTabContent(repository, owner = owner).testFlow {
                val initial = awaitItem()
                initial.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))

                // when
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                runCurrent()

                // then
                expectNoEvents()
                assertTrue(repository.requests.tryReceive().isFailure)
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                runCurrent()
                initial.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                awaitItem()
                repository.requests.receive().complete(Result.success(snapshot(1)))
                assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should ignore callbacks before first START and remain retryable once visible`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner(Lifecycle.State.CREATED)
            nearbyTabContent(repository, owner = owner).testFlow {
                val initial = awaitItem()

                // when
                initial.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                initial.eventSink(
                    NearbyVehicleMapScreenEvent.LocationAccessBlocked(RiderLocationBlockedReason.AccessDenied),
                )
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                runCurrent()

                // then
                expectNoEvents()
                assertTrue(repository.requests.tryReceive().isFailure)
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                runCurrent()
                initial.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                awaitItem()
                repository.requests.receive().complete(Result.success(snapshot(1)))
                assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should revalidate cached location preserve its snapshot and allow fallback retry`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner()
            nearbyTabContent(repository, owner = owner).testFlow {
                val loaded = resolveLocation(repository, loadedAtMillis = Long.MAX_VALUE)
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                runCurrent()
                expectNoEvents()

                // when
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                val checking = awaitItem()
                checking.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(0))
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 2)
                runCurrent()

                // then
                assertEquals(loaded.featureState.snapshotState, checking.featureState.snapshotState)
                assertEquals(RiderLocationState.Resolving, checking.featureState.riderLocationState)
                assertFalse(checking.featureState.canRequestRefresh())
                assertTrue(repository.requests.tryReceive().isFailure)
                checking.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                val fallback = awaitItem()
                assertEquals(
                    RiderLocationState.TemporarilyUnavailable(RIDER_LOCATION),
                    fallback.featureState.riderLocationState,
                )
                assertTrue(fallback.featureState.canRequestRefresh())
                fallback.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(0))
                awaitItem()
                repository.requests.receive().complete(Result.success(snapshot(2)))
                assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should age retained failures on START while keeping blocked decisions unchanged`() =
        runTest {
            for (blocked in listOf(false, true)) {
                // given
                val repository = ControlledFleetRepository()
                val owner = TabContentOwner()
                nearbyTabContent(repository, owner = owner).testFlow {
                    resolveLocation(repository).eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(0))
                    awaitItem()
                    repository.requests.receive().complete(Result.failure(NearbyFleetRepositoryException()))
                    val failed = awaitItem()
                    val ready =
                        if (blocked) {
                            failed.eventSink(
                                NearbyVehicleMapScreenEvent.LocationAccessBlocked(
                                    RiderLocationBlockedReason.AccessDenied,
                                ),
                            )
                            awaitItem()
                        } else {
                            failed
                        }
                    owner.lifecycle.currentState = Lifecycle.State.CREATED
                    runCurrent()

                    // when
                    owner.lifecycle.currentState = Lifecycle.State.STARTED
                    runCurrent()

                    // then
                    if (blocked) {
                        expectNoEvents()
                    } else {
                        val checking = awaitItem()
                        assertEquals(ready.featureState.snapshotState, checking.featureState.snapshotState)
                        assertEquals(
                            NearbyVehicleMapOverlayState.BlockingFailure,
                            checking.featureState.mapOverlayState,
                        )
                        checking.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                        assertEquals(
                            NearbyVehicleMapOverlayState.BlockingFailure,
                            awaitItem().featureState.mapOverlayState,
                        )
                    }
                    assertTrue(repository.requests.tryReceive().isFailure)
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should reject noncooperative old completions while newer work is pending or complete`() =
        runTest {
            for (oldResult in listOf(
                Result.success(snapshot(99)),
                Result.failure(CancellationException()),
                Result.failure(IllegalStateException("old failure")),
            )) {
                for (newerComplete in listOf(false, true)) {
                    val repository = LateCompletingFleetRepository()
                    val owner = TabContentOwner()
                    nearbyTabContent(repository, owner = owner).testFlow {
                        try {
                            // given
                            resolveLocation(
                                repository.requests,
                            ).eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(0))
                            awaitItem()
                            val older = repository.requests.receive()
                            owner.lifecycle.currentState = Lifecycle.State.CREATED
                            awaitItem()
                            owner.lifecycle.currentState = Lifecycle.State.STARTED
                            awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                            awaitItem()
                            val newer = repository.requests.receive()
                            if (newerComplete) {
                                newer.complete(Result.success(snapshot(2)))
                                awaitItem()
                            }

                            // when
                            older.complete(oldResult)
                            runCurrent()

                            // then
                            expectNoEvents()
                            assertTrue(repository.requests.tryReceive().isFailure)
                            if (!newerComplete) {
                                newer.complete(Result.success(snapshot(2)))
                                assertEquals(
                                    NearbyVehicleSnapshotState.Loaded(snapshot(2)),
                                    awaitItem().featureState.snapshotState,
                                )
                            }
                            cancelAndIgnoreRemainingEvents()
                        } finally {
                            repository.completePendingRequests()
                        }
                    }
                }
            }
        }
}
