package studio.mekate.mobi.home

import androidx.lifecycle.Lifecycle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.TabContentOwner
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.currentValueForRefresh
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import app.cash.turbine.test as testFlow

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class HomeForegroundLifetimeTest {
    @Test
    fun `should preserve exact ready Home state across host stop and start without fetching`() =
        runTest {
            for (target in readyStates()) {
                // given
                val repository = ControlledCounterRepository()
                val owner = TabContentOwner()
                homeTabContent(repository, owner = owner).testFlow {
                    val previous = reachState(repository, target)

                    // when
                    owner.lifecycle.currentState = Lifecycle.State.CREATED
                    runCurrent()
                    expectNoEvents()
                    owner.lifecycle.currentState = Lifecycle.State.STARTED
                    runCurrent()

                    // then
                    expectNoEvents()
                    assertTrue(repository.requests.tryReceive().isFailure)
                    previous.eventSink(HomeScreenEvent.RefreshClicked)
                    awaitItem()
                    val retry = repository.requests.receive()
                    assertEquals(target.currentValueForRefresh(), retry.currentValue)
                    retry.response.complete(Result.success(13))
                    assertEquals(13, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should cancel Home refresh synchronously on stop and restore its ready state`() =
        runTest {
            for (target in readyStates()) {
                // given
                val repository = ControlledCounterRepository()
                val owner = TabContentOwner()
                homeTabContent(repository, owner = owner).testFlow {
                    val previous = reachState(repository, target)
                    previous.eventSink(HomeScreenEvent.RefreshClicked)
                    assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                    val request = repository.requests.receive()

                    // when: a paused but visible host stays STARTED; STOP moves below it.
                    owner.lifecycle.currentState = Lifecycle.State.STARTED
                    assertFalse(request.job.isCancelled)
                    owner.lifecycle.currentState = Lifecycle.State.CREATED

                    // then: cancellation must not wait for a recomposition/frame.
                    assertTrue(request.job.isCancelled)
                    assertTrue(request.response.isCancelled)
                    val restored = awaitItem()
                    assertEquals(previous.featureState, restored.featureState)
                    previous.eventSink(HomeScreenEvent.RefreshClicked)
                    restored.eventSink(HomeScreenEvent.RefreshClicked)
                    runCurrent()
                    assertTrue(repository.requests.tryReceive().isFailure)
                    expectNoEvents()
                    owner.lifecycle.currentState = Lifecycle.State.STARTED
                    runCurrent()
                    previous.eventSink(HomeScreenEvent.RefreshClicked)
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
    fun `should ignore Home callbacks before the host starts and admit them when visible`() =
        runTest {
            // given
            val repository = ControlledCounterRepository()
            val owner = TabContentOwner(Lifecycle.State.CREATED)
            homeTabContent(repository, owner = owner).testFlow {
                val initial = awaitItem()

                // when
                initial.eventSink(HomeScreenEvent.RefreshClicked)
                runCurrent()

                // then
                assertTrue(repository.requests.tryReceive().isFailure)
                expectNoEvents()
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                runCurrent()
                initial.eventSink(HomeScreenEvent.RefreshClicked)
                awaitItem()
                repository.requests
                    .receive()
                    .response
                    .complete(Result.success(8))
                assertEquals(8, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should cancel queued Home refresh admission when its host stops`() =
        runTest {
            // given
            val repository = ControlledCounterRepository()
            val owner = TabContentOwner()
            homeTabContent(repository, owner = owner).testFlow {
                val previous = reachState(repository, CounterLoadable.Loaded(8))

                // when: stop before the queued refresh coroutine can enter loading.
                previous.eventSink(HomeScreenEvent.RefreshClicked)
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                runCurrent()

                // then
                expectNoEvents()
                assertTrue(repository.requests.tryReceive().isFailure)
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                runCurrent()
                previous.eventSink(HomeScreenEvent.RefreshClicked)
                awaitItem()
                val retry = repository.requests.receive()
                assertEquals(8, retry.currentValue)
                retry.response.complete(Result.success(13))
                assertEquals(13, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should reject old Home cancellation after a newer foreground request starts or finishes`() =
        runTest {
            val lateResults =
                listOf<Result<Int>>(
                    Result.success(99),
                    Result.failure(CancellationException()),
                    Result.failure(IllegalStateException("Late failure")),
                )
            for (finishNewFirst in listOf(false, true)) {
                for (lateResult in lateResults) {
                    val repository = LateCompletingCounterRepository()
                    val owner = TabContentOwner()
                    homeTabContent(repository, owner = owner).testFlow {
                        try {
                            // given
                            awaitItem().eventSink(HomeScreenEvent.RefreshClicked)
                            awaitItem()
                            repository.requests
                                .receive()
                                .response
                                .complete(Result.success(8))
                            val previous = awaitItem()
                            previous.eventSink(HomeScreenEvent.RefreshClicked)
                            awaitItem()
                            val old = repository.requests.receive()
                            owner.lifecycle.currentState = Lifecycle.State.CREATED
                            assertTrue(old.job.isCancelled)
                            assertEquals(previous.featureState, awaitItem().featureState)
                            owner.lifecycle.currentState = Lifecycle.State.STARTED
                            runCurrent()
                            previous.eventSink(HomeScreenEvent.RefreshClicked)
                            awaitItem()
                            val newer = repository.requests.receive()
                            if (finishNewFirst) {
                                newer.response.complete(Result.success(13))
                                assertEquals(
                                    13,
                                    assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value,
                                )
                            }

                            // when
                            old.response.complete(lateResult)
                            runCurrent()

                            // then
                            expectNoEvents()
                            assertFalse(newer.job.isCancelled)
                            if (!finishNewFirst) {
                                newer.response.complete(Result.success(13))
                                assertEquals(
                                    13,
                                    assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value,
                                )
                            }
                            assertTrue(repository.requests.tryReceive().isFailure)
                            cancelAndIgnoreRemainingEvents()
                        } finally {
                            repository.completePendingRequests()
                        }
                    }
                }
            }
        }
}
