package studio.mekate.mobi.nearbyvehiclemap

import androidx.compose.runtime.mutableStateOf
import app.cash.turbine.ReceiveTurbine
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.AppDestination
import studio.mekate.mobi.core.NearbyFleetRepositoryException
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFailureReason
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
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
class NearbyTabLifetimeTest {
    @Test
    fun `should retain the snapshot while location is revalidated on tab return`() =
        runTest {
            for (location in listOf(RIDER_LOCATION, RiderLocation(latitude = 55.68, longitude = 12.57))) {
                val repository = ControlledFleetRepository()
                val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
                nearbyTabContent(repository, destination).testFlow {
                    // given
                    val loaded = resolveLocation(repository, loadedAtMillis = Long.MAX_VALUE)
                    destination.value = AppDestination.NativeHome
                    runCurrent()
                    destination.value = AppDestination.NearbyVehicleMap

                    // when
                    val checking = awaitItem()
                    val presentation = checking.featureState.toNearbyVehicleMapPresentation()
                    checking.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                    runCurrent()

                    // then
                    assertEquals(loaded.featureState.snapshotState, checking.featureState.snapshotState)
                    assertEquals(RiderLocationState.Resolving, checking.featureState.riderLocationState)
                    assertIs<NearbyVehicleMapContentPresentation.RiderCentered>(presentation.mapContent)
                    assertEquals(
                        "Checking location",
                        assertIs<NearbyVehicleMapOverlayPresentation.Banner>(presentation.overlay).headline,
                    )
                    assertFalse(presentation.canRequestRefresh)
                    assertFalse(presentation.canInteractWithVehicles)
                    assertTrue(repository.requests.tryReceive().isFailure)
                    checking.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(location))
                    assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                    repository.requests.receive().complete(Result.success(snapshot(sequence = 2, location = location)))
                    assertEquals(location, repository.fleetRequests.last().riderLocation)
                    assertEquals(
                        NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2, location = location)),
                        awaitItem().featureState.snapshotState,
                    )
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should retain blocked outcomes and recover only after precise location is resolved`() =
        runTest {
            for (hasSnapshot in listOf(false, true)) {
                for (reason in RiderLocationBlockedReason.entries) {
                    val repository = ControlledFleetRepository()
                    val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
                    nearbyTabContent(repository, destination).testFlow {
                        // given
                        val ready = readyState(repository, hasSnapshot)
                        ready.eventSink(NearbyVehicleMapScreenEvent.LocationAccessBlocked(reason))
                        val blocked = awaitItem()
                        destination.value = AppDestination.NativeHome
                        runCurrent()
                        destination.value = AppDestination.NearbyVehicleMap

                        // when
                        val returned = awaitItem()
                        returned.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                        runCurrent()

                        // then
                        assertEquals(blocked.featureState, returned.featureState)
                        assertEquals(
                            NearbyVehicleMapContentPresentation.WaitingForRider,
                            returned.featureState.toNearbyVehicleMapPresentation().mapContent,
                        )
                        assertTrue(repository.requests.tryReceive().isFailure)
                        expectNoEvents()
                        returned.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                        awaitItem()
                        repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                        val recovered = awaitItem().featureState
                        assertIs<RiderLocationState.Available>(recovered.riderLocationState)
                        assertEquals(NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2)), recovered.snapshotState)
                        cancelAndIgnoreRemainingEvents()
                    }
                }
            }
        }

    @Test
    fun `should reuse the last position when revalidation reports temporary location loss`() =
        runTest {
            for (hasSnapshot in listOf(false, true)) {
                val repository = ControlledFleetRepository()
                val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
                nearbyTabContent(repository, destination).testFlow {
                    // given
                    readyState(
                        repository,
                        hasSnapshot,
                    ).eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                    val degraded = awaitItem()
                    destination.value = AppDestination.NativeHome
                    runCurrent()
                    destination.value = AppDestination.NearbyVehicleMap
                    val checking = awaitItem()

                    // when
                    checking.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                    val returned = awaitItem().featureState

                    // then
                    assertEquals(degraded.featureState, returned)
                    assertEquals(RiderLocationState.TemporarilyUnavailable(RIDER_LOCATION), returned.riderLocationState)
                    advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                    runCurrent()
                    assertTrue(repository.requests.tryReceive().isFailure)
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should cancel hidden initial and manual work without retaining loading`() =
        runTest {
            for (hasSnapshot in listOf(false, true)) {
                val repository = ControlledFleetRepository()
                val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
                nearbyTabContent(repository, destination).testFlow {
                    // given
                    startRefresh(repository, hasSnapshot)
                    val request = repository.requests.receive()
                    val job = repository.jobs.last()

                    // when
                    destination.value = AppDestination.NativeHome
                    runCurrent()
                    advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                    runCurrent()
                    destination.value = AppDestination.NearbyVehicleMap
                    val returned = awaitItem()

                    // then
                    assertTrue(job.isCancelled)
                    assertTrue(request.isCancelled)
                    assertFalse(returned.featureState.snapshotState.isRefreshInFlight())
                    val expected =
                        if (hasSnapshot) {
                            NearbyVehicleSnapshotState.Loaded(
                                snapshot(sequence = 1),
                            )
                        } else {
                            NearbyVehicleSnapshotState.Initial
                        }
                    assertEquals(expected, returned.featureState.snapshotState)
                    assertTrue(repository.requests.tryReceive().isFailure)
                    returned.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                    awaitItem()
                    repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                    assertEquals(
                        NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2)),
                        awaitItem().featureState.snapshotState,
                    )
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should stop hidden automatic work and restart the timer after location revalidation`() =
        runTest {
            val repository = ControlledFleetRepository()
            val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
            nearbyTabContent(repository, destination).testFlow {
                // given
                resolveLocation(repository)
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                awaitItem()
                val request = repository.requests.receive()
                destination.value = AppDestination.NativeHome
                runCurrent()

                // when
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                runCurrent()
                destination.value = AppDestination.NearbyVehicleMap
                val checking = awaitItem()
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 2)
                runCurrent()

                // then
                assertTrue(request.isCancelled)
                assertEquals(
                    NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 1)),
                    checking.featureState.snapshotState,
                )
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                checking.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                assertIs<RiderLocationState.TemporarilyUnavailable>(awaitItem().featureState.riderLocationState)
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

    @Test
    fun `should apply shared expiry policy before using a retained failure with fallback location`() =
        runTest {
            val repository = ControlledFleetRepository()
            val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
            nearbyTabContent(repository, destination).testFlow {
                // given
                resolveLocation(repository).eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                awaitItem()
                repository.requests.receive().complete(Result.failure(NearbyFleetRepositoryException()))
                assertEquals(NearbyVehicleMapOverlayState.StaleIndicator, awaitItem().featureState.mapOverlayState)
                destination.value = AppDestination.NativeHome
                runCurrent()
                destination.value = AppDestination.NearbyVehicleMap
                val checking = awaitItem()

                // when
                checking.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                val returned = awaitItem()
                val failure =
                    assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(returned.featureState.snapshotState)

                // then
                assertEquals(1L, failure.snapshot.sequence)
                assertEquals(NearbyVehicleMapFailureReason.RepositoryUnavailable, failure.reason)
                assertEquals(NearbyVehicleMapOverlayState.BlockingFailure, returned.featureState.mapOverlayState)
                val presentation = returned.featureState.toNearbyVehicleMapPresentation()
                assertFalse(presentation.canInteractWithVehicles)
                assertTrue(presentation.canRequestRefresh)
                returned.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                awaitItem()
                repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should keep a blocked decision ahead of queued precise location work`() =
        runTest {
            val repository = ControlledFleetRepository()
            val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
            nearbyTabContent(repository, destination).testFlow {
                // given
                resolveLocation(repository)
                destination.value = AppDestination.NativeHome
                runCurrent()
                destination.value = AppDestination.NearbyVehicleMap
                val checking = awaitItem()

                // when
                checking.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                checking.eventSink(
                    NearbyVehicleMapScreenEvent.LocationAccessBlocked(RiderLocationBlockedReason.AccessDenied),
                )
                runCurrent()
                val blocked = awaitItem().featureState

                // then
                assertEquals(RiderLocationState.Denied, blocked.riderLocationState)
                assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(blocked.snapshotState)
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should reject hidden completions and old callbacks after a newer snapshot finishes`() =
        runTest {
            val repository = LateCompletingFleetRepository()
            val destination = mutableStateOf(AppDestination.NearbyVehicleMap)
            nearbyTabContent(repository, destination).testFlow {
                try {
                    // given
                    resolveLocation(
                        repository.requests,
                    ).eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                    val olderState = awaitItem()
                    val older = repository.requests.receive()
                    destination.value = AppDestination.NativeHome
                    runCurrent()
                    destination.value = AppDestination.NearbyVehicleMap
                    awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                    awaitItem()
                    repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                    awaitItem()

                    // when
                    older.complete(Result.success(snapshot(sequence = 99)))
                    olderState.eventSink(
                        NearbyVehicleMapScreenEvent.LocationAccessBlocked(RiderLocationBlockedReason.AccessDenied),
                    )
                    olderState.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                    olderState.eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
                    olderState.eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
                    runCurrent()
                    expectNoEvents()
                    destination.value = AppDestination.NativeHome
                    runCurrent()
                    destination.value = AppDestination.NearbyVehicleMap

                    // then
                    val returned = awaitItem().featureState
                    assertEquals(NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2)), returned.snapshotState)
                    assertEquals(RiderLocationState.Resolving, returned.riderLocationState)
                    assertTrue(repository.requests.tryReceive().isFailure)
                    cancelAndIgnoreRemainingEvents()
                } finally {
                    repository.completePendingRequests()
                }
            }
        }

    private suspend fun ReceiveTurbine<NearbyVehicleMapScreenState>.readyState(
        repository: ControlledFleetRepository,
        hasSnapshot: Boolean,
    ): NearbyVehicleMapScreenState {
        if (hasSnapshot) return resolveLocation(repository, loadedAtMillis = Long.MAX_VALUE)
        awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
        awaitItem()
        repository.requests.receive().complete(Result.failure(NearbyFleetRepositoryException()))
        return awaitItem()
    }
}
