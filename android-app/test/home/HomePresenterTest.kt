package studio.mekate.mobi.home

import app.cash.molecule.RecompositionMode
import app.cash.molecule.moleculeFlow
import app.cash.turbine.ReceiveTurbine
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.job
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.core.CounterRepositoryException
import studio.mekate.mobi.feature.home.CounterLoadFailureReason
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.currentValueForRefresh
import studio.mekate.mobi.feature.home.currentValueOrNull
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import app.cash.turbine.test as testFlow

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class HomePresenterTest {
    @Test
    fun `should admit one queued refresh and another after completion`() =
        runTest {
            // given
            val repository = ControlledCounterRepository()
            queuedPresenter(repository).testFlow {
                val initial = awaitItem()

                // when
                initial.eventSink(HomeScreenEvent.RefreshClicked)
                initial.eventSink(HomeScreenEvent.RefreshClicked)
                runCurrent()

                // then
                assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                val request = repository.requests.receive()
                assertEquals(0, request.currentValue)
                assertTrue(repository.requests.tryReceive().isFailure)
                initial.eventSink(HomeScreenEvent.RefreshClicked)
                runCurrent()
                expectNoEvents()
                assertTrue(repository.requests.tryReceive().isFailure)
                request.response.complete(Result.success(1))
                val loaded = awaitItem()
                assertEquals(1, assertIs<CounterLoadable.Loaded>(loaded.featureState.counterLoadable).value)
                loaded.eventSink(HomeScreenEvent.RefreshClicked)
                assertEquals(
                    1,
                    assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable).previousValue,
                )
                val next = repository.requests.receive()
                assertEquals(1, next.currentValue)
                next.response.complete(Result.success(2))
                assertEquals(2, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)
                assertEquals(0L, testScheduler.currentTime)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should use the current counter when an older callback requests refresh`() =
        runTest {
            // given
            val repository = ControlledCounterRepository()
            queuedPresenter(repository).testFlow {
                val initial = awaitItem()
                initial.eventSink(HomeScreenEvent.RefreshClicked)
                assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                repository.requests
                    .receive()
                    .response
                    .complete(Result.success(8))
                assertEquals(8, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)

                // when
                initial.eventSink(HomeScreenEvent.RefreshClicked)
                runCurrent()

                // then
                assertEquals(
                    8,
                    assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable).previousValue,
                )
                val request = repository.requests.receive()
                assertEquals(8, request.currentValue)
                request.response.complete(Result.success(13))
                assertEquals(13, assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value)
                assertTrue(repository.requests.tryReceive().isFailure)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should allow repository failure retry with absent and previous counter values`() =
        runTest {
            // given
            val repository = ControlledCounterRepository()
            queuedPresenter(repository).testFlow {
                var ready = awaitItem()
                for (previousValue in listOf(null, 8)) {
                    // when
                    ready.eventSink(HomeScreenEvent.RefreshClicked)
                    assertEquals(
                        previousValue,
                        assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable).previousValue,
                    )
                    val request = repository.requests.receive()
                    assertEquals(previousValue ?: 0, request.currentValue)
                    request.response.complete(Result.failure(CounterRepositoryException()))

                    // then
                    val failed = awaitItem()
                    val error = assertIs<CounterLoadable.Error>(failed.featureState.counterLoadable)
                    assertEquals(previousValue, error.previousValue)
                    assertEquals(CounterLoadFailureReason.RepositoryUnavailable, error.reason)
                    failed.eventSink(HomeScreenEvent.RefreshClicked)
                    assertEquals(
                        previousValue,
                        assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable).previousValue,
                    )
                    val retry = repository.requests.receive()
                    assertEquals(previousValue ?: 0, retry.currentValue)
                    retry.response.complete(Result.success(8))
                    ready = awaitItem()
                    assertEquals(8, assertIs<CounterLoadable.Loaded>(ready.featureState.counterLoadable).value)
                    assertTrue(repository.requests.tryReceive().isFailure)
                }
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should restore exact previous Home state and allow retry after cancellation`() =
        runTest {
            for (cancelJob in listOf(false, true)) {
                for (previousLoadable in readyStates()) {
                    // given
                    val repository = ControlledCounterRepository()
                    queuedPresenter(repository).testFlow {
                        val previous = reachState(repository, previousLoadable)
                        previous.eventSink(HomeScreenEvent.RefreshClicked)
                        assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                        val request = repository.requests.receive()

                        // when
                        if (cancelJob) {
                            request.job.cancel()
                        } else {
                            request.response.complete(Result.failure(CancellationException()))
                        }
                        val restored = awaitItem()
                        request.job.join()

                        // then
                        assertEquals(previous.featureState, restored.featureState)
                        assertTrue(request.job.isCancelled, "Recovery must preserve request cancellation")
                        assertTrue(repository.requests.tryReceive().isFailure)
                        restored.eventSink(HomeScreenEvent.RefreshClicked)
                        assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                        val retry = repository.requests.receive()
                        assertEquals(previousLoadable.currentValueForRefresh(), retry.currentValue)
                        retry.response.complete(Result.success(13))
                        assertEquals(
                            13,
                            assertIs<CounterLoadable.Loaded>(awaitItem().featureState.counterLoadable).value,
                        )
                        assertTrue(repository.requests.tryReceive().isFailure)
                        cancelAndIgnoreRemainingEvents()
                    }
                }
            }
        }

    @Test
    fun `should cancel active refresh when the presenter leaves composition`() =
        runTest {
            // given
            val repository = ControlledCounterRepository()
            lateinit var request: PendingCounterRequest
            queuedPresenter(repository).testFlow {
                awaitItem().eventSink(HomeScreenEvent.RefreshClicked)
                assertIs<CounterLoadable.Loading>(awaitItem().featureState.counterLoadable)
                request = repository.requests.receive()
                assertFalse(request.response.isCancelled)

                // when
                cancelAndIgnoreRemainingEvents()
            }
            runCurrent()

            // then
            assertTrue(request.response.isCancelled)
            assertTrue(request.job.isCancelled)
            assertTrue(repository.requests.tryReceive().isFailure)
        }

    private suspend fun ReceiveTurbine<HomeScreenState>.reachState(
        repository: ControlledCounterRepository,
        target: CounterLoadable,
    ): HomeScreenState {
        var ready = awaitItem()
        val value = target.currentValueOrNull()
        if (value != null) {
            ready.eventSink(HomeScreenEvent.RefreshClicked)
            awaitItem()
            repository.requests
                .receive()
                .response
                .complete(Result.success(value))
            ready = awaitItem()
        }
        if (target is CounterLoadable.Error) {
            ready.eventSink(HomeScreenEvent.RefreshClicked)
            awaitItem()
            val failure =
                when (target.reason) {
                    CounterLoadFailureReason.RepositoryUnavailable -> CounterRepositoryException()
                    CounterLoadFailureReason.Unexpected -> IllegalStateException("Unexpected repository failure")
                }
            repository.requests
                .receive()
                .response
                .complete(Result.failure(failure))
            ready = awaitItem()
        }
        assertEquals(target, ready.featureState.counterLoadable)
        return ready
    }

    private fun readyStates(): List<CounterLoadable> =
        listOf(
            CounterLoadable.Initial,
            CounterLoadable.Loaded(0),
            CounterLoadable.Loaded(8),
            CounterLoadable.Error(null, CounterLoadFailureReason.RepositoryUnavailable),
            CounterLoadable.Error(8, CounterLoadFailureReason.RepositoryUnavailable),
            CounterLoadable.Error(null, CounterLoadFailureReason.Unexpected),
            CounterLoadable.Error(8, CounterLoadFailureReason.Unexpected),
        )

    private fun TestScope.queuedPresenter(repository: CounterRepository): Flow<HomeScreenState> {
        val presenter = HomePresenter(HomeFeatureService(repository))
        return moleculeFlow(RecompositionMode.Immediate) { presenter.present() }
            .flowOn(StandardTestDispatcher(testScheduler))
    }
}

private data class PendingCounterRequest(
    val currentValue: Int,
    val response: CompletableDeferred<Result<Int>>,
    val job: Job,
)

private class ControlledCounterRepository : CounterRepository {
    val requests = Channel<PendingCounterRequest>(Channel.UNLIMITED)

    override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int {
        val requestJob = currentCoroutineContext().job
        val response = CompletableDeferred<Result<Int>>(requestJob)
        requests.send(PendingCounterRequest(currentCounterValue, response, requestJob))
        // Throw from the repository; failing the deferred child would cancel its parent job.
        return response.await().getOrThrow()
    }
}
