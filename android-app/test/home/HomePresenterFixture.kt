package studio.mekate.mobi.home

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import app.cash.turbine.ReceiveTurbine
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.job
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.withContext
import studio.mekate.mobi.AppDestination
import studio.mekate.mobi.NativeTabState
import studio.mekate.mobi.TabContentOwner
import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.core.CounterRepositoryException
import studio.mekate.mobi.di.SharedApplicationGraph
import studio.mekate.mobi.di.SharedDependencies
import studio.mekate.mobi.feature.home.CounterLoadFailureReason
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.currentValueOrNull
import studio.mekate.mobi.nativeTabContent
import kotlin.test.assertEquals

internal suspend fun ReceiveTurbine<HomeScreenState>.reachState(
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

internal fun readyStates(): List<CounterLoadable> =
    listOf(
        CounterLoadable.Initial,
        CounterLoadable.Loaded(0),
        CounterLoadable.Loaded(8),
        CounterLoadable.Error(null, CounterLoadFailureReason.RepositoryUnavailable),
        CounterLoadable.Error(8, CounterLoadFailureReason.RepositoryUnavailable),
        CounterLoadable.Error(null, CounterLoadFailureReason.Unexpected),
        CounterLoadable.Error(8, CounterLoadFailureReason.Unexpected),
    )

internal data class PendingCounterRequest(
    val currentValue: Int,
    val response: CompletableDeferred<Result<Int>>,
    val job: Job,
)

internal class ControlledCounterRepository : CounterRepository {
    val requests = Channel<PendingCounterRequest>(Channel.UNLIMITED)

    override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int {
        val requestJob = currentCoroutineContext().job
        val response = CompletableDeferred<Result<Int>>(requestJob)
        requests.send(PendingCounterRequest(currentCounterValue, response, requestJob))
        // Throw from the repository; failing the deferred child would cancel its parent job.
        return response.await().getOrThrow()
    }
}

internal fun TestScope.homeTabContent(
    repository: CounterRepository,
    destination: State<AppDestination> = mutableStateOf(AppDestination.NativeHome),
    owner: TabContentOwner? = null,
): Flow<HomeScreenState> {
    val defaults = SharedDependencies.createDefaultGraph()
    val sharedGraph =
        object : SharedApplicationGraph by defaults {
            override val counterRepository = repository
            override val homeFeatureService = HomeFeatureService(repository)
        }
    return nativeTabContent(destination, sharedGraph, owner)
        .filterIsInstance<NativeTabState.Home>()
        .map { it.state }
}

internal class LateCompletingCounterRepository : CounterRepository {
    val requests = Channel<PendingCounterRequest>(Channel.UNLIMITED)
    private val pending = mutableListOf<CompletableDeferred<Result<Int>>>()

    override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int {
        val job = currentCoroutineContext().job
        return withContext(NonCancellable) {
            val result = CompletableDeferred<Result<Int>>()
            pending.add(result)
            requests.send(PendingCounterRequest(currentCounterValue, result, job))
            result.await().getOrThrow()
        }
    }

    fun completePendingRequests() {
        pending.forEach { it.complete(Result.failure(CancellationException())) }
    }
}
