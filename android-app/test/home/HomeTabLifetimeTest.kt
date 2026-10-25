package studio.mekate.mobi.home

import androidx.compose.runtime.mutableStateOf
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.AppDestination
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.currentValueForRefresh
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import app.cash.turbine.test as testFlow

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class HomeTabLifetimeTest {
    @Test
    fun `should retain ready Home state across tab return without refetching`() =
        runTest {
            for (target in readyStates()) {
                // given
                val repository = ControlledCounterRepository()
                val destination = mutableStateOf(AppDestination.NativeHome)
                homeTabContent(repository, destination).testFlow {
                    val previous = reachState(repository, target)

                    // when
                    destination.value = AppDestination.NearbyVehicleMap
                    runCurrent()
                    expectNoEvents()
                    destination.value = AppDestination.NativeHome
                    val returned = awaitItem()

                    // then
                    assertEquals(previous.featureState, returned.featureState)
                    assertTrue(repository.requests.tryReceive().isFailure)
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should cancel hidden Home work and return to its last ready state`() =
        runTest {
            for (target in readyStates()) {
                // given
                val repository = ControlledCounterRepository()
                val destination = mutableStateOf(AppDestination.NativeHome)
                homeTabContent(repository, destination).testFlow {
                    val previous = reachState(repository, target)
                    previous.eventSink(HomeScreenEvent.RefreshClicked)
                    assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                    val request = repository.requests.receive()

                    // when
                    destination.value = AppDestination.NearbyVehicleMap
                    runCurrent()

                    // then
                    assertTrue(request.job.isCancelled)
                    assertTrue(request.response.isCancelled)
                    expectNoEvents()
                    destination.value = AppDestination.NativeHome
                    val returned = awaitItem()
                    assertEquals(previous.featureState, returned.featureState)
                    returned.eventSink(HomeScreenEvent.RefreshClicked)
                    assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                    val retry = repository.requests.receive()
                    assertEquals(target.currentValueForRefresh(), retry.currentValue)
                    retry.response.complete(Result.success(13))
                    assertEquals(13, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should reject late hidden completion after a newer Home request finishes`() =
        runTest {
            val repository = LateCompletingCounterRepository()
            val destination = mutableStateOf(AppDestination.NativeHome)
            homeTabContent(repository, destination).testFlow {
                try {
                    // given
                    awaitItem().eventSink(HomeScreenEvent.RefreshClicked)
                    awaitItem()
                    val older = repository.requests.receive()
                    destination.value = AppDestination.NearbyVehicleMap
                    runCurrent()
                    assertTrue(older.job.isCancelled)
                    destination.value = AppDestination.NativeHome
                    val returned = awaitItem()
                    assertEquals(CounterLoadable.Initial, returned.featureState.counterLoadable)
                    returned.eventSink(HomeScreenEvent.RefreshClicked)
                    awaitItem()
                    repository.requests
                        .receive()
                        .response
                        .complete(Result.success(13))
                    assertEquals(13, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)

                    // when
                    older.response.complete(Result.success(99))
                    runCurrent()
                    expectNoEvents()
                    destination.value = AppDestination.NearbyVehicleMap
                    runCurrent()
                    destination.value = AppDestination.NativeHome

                    // then
                    assertEquals(13, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)
                    cancelAndIgnoreRemainingEvents()
                } finally {
                    repository.completePendingRequests()
                }
            }
        }
}
