package studio.mekate.mobi.nearbyvehiclemap

import androidx.lifecycle.Lifecycle
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.TabContentOwner
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import app.cash.turbine.test as testFlow

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class NearbyForegroundTimerTest {
    @Test
    fun `should keep the timer running while the host is paused but STARTED`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner()
            nearbyTabContent(repository, owner = owner).testFlow {
                resolveLocation(repository)
                advanceTimeBy(REFRESH_INTERVAL_MILLIS / 2)

                // when
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                advanceTimeBy(REFRESH_INTERVAL_MILLIS / 2)
                runCurrent()

                // then
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                val automatic = repository.requests.receive()
                assertFalse(automatic.isCancelled)
                automatic.complete(Result.success(snapshot(sequence = 2)))
                assertEquals(
                    NearbyVehicleSnapshotState.Loaded(snapshot(sequence = 2)),
                    awaitItem().featureState.snapshotState,
                )
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should stop timer ticks while hidden and restart a full delay on each START`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner()
            nearbyTabContent(repository, owner = owner).testFlow {
                resolveLocation(repository)
                for (sequence in 2L..3L) {
                    advanceTimeBy(REFRESH_INTERVAL_MILLIS / 2)

                    // when
                    owner.lifecycle.currentState = Lifecycle.State.CREATED
                    advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                    runCurrent()

                    // then
                    assertTrue(repository.requests.tryReceive().isFailure)
                    expectNoEvents()
                    owner.lifecycle.currentState = Lifecycle.State.STARTED
                    awaitItem().eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                    awaitItem()
                    runCurrent()
                    advanceTimeBy(REFRESH_INTERVAL_MILLIS - 1)
                    runCurrent()
                    assertTrue(repository.requests.tryReceive().isFailure)
                    expectNoEvents()
                    advanceTimeBy(1)
                    runCurrent()
                    assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                    repository.requests.receive().complete(Result.success(snapshot(sequence = sequence)))
                    assertEquals(
                        NearbyVehicleSnapshotState.Loaded(snapshot(sequence = sequence)),
                        awaitItem().featureState.snapshotState,
                    )
                    assertTrue(repository.requests.tryReceive().isFailure)
                }
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should wait for location revalidation before restarting timer refresh`() =
        runTest {
            // given
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner()
            nearbyTabContent(repository, owner = owner).testFlow {
                resolveLocation(repository)
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                runCurrent()
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                val checking = awaitItem()

                // when
                advanceTimeBy(REFRESH_INTERVAL_MILLIS * 3)
                runCurrent()

                // then
                assertTrue(repository.requests.tryReceive().isFailure)
                checking.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                awaitItem()
                advanceTimeBy(REFRESH_INTERVAL_MILLIS)
                runCurrent()
                assertIs<NearbyVehicleSnapshotState.Refreshing>(awaitItem().featureState.snapshotState)
                repository.requests.receive().complete(Result.success(snapshot(sequence = 2)))
                assertIs<NearbyVehicleSnapshotState.Loaded>(awaitItem().featureState.snapshotState)
                cancelAndIgnoreRemainingEvents()
            }
        }
}
