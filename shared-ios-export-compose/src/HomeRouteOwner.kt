@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package studio.mekate.mobi.export.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.window.ComposeUIViewController
import kotlinx.atomicfu.atomic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.HomeFeatureState
import studio.mekate.mobi.feature.home.currentValueForRefresh
import studio.mekate.mobi.ui.home.HomeContent
import kotlin.coroutines.cancellation.CancellationException

// App route ownership over the actual Compose owner. Limits are explicit reviewed
// settings. A reservation exists before coroutine construction, registration or launch.
class HomeRouteOwner(
    private val service: HomeFeatureService,
    private val maxJobs: Int,
) {
    init {
        require(maxJobs > 0)
    }

    private class Reservation {
        val job = atomic<Job?>(null)
    }

    private data class Ownership(
        val retired: Boolean,
        val reservations: List<Reservation>,
    )

    private val ownership = atomic(Ownership(false, emptyList()))
    private val accepted = atomic(0)
    private val rejected = atomic(0)
    private val delivered = atomic(0)
    private val cancelled = atomic(0)
    private val finished = atomic(0)
    private val retireTransitions = atomic(0)
    private val lateResultsRejected = atomic(0)
    private val publications = atomic(0)
    private val releases = atomic(0)
    private val maximum = atomic(0)

    val isOpen: Boolean get() = !ownership.value.retired
    val isDrained: Boolean get() = ownership.value.let { it.retired && it.reservations.isEmpty() }

    fun usesService(other: HomeFeatureService): Boolean = service === other

    fun createViewController() = ComposeUIViewController { OwnedHomeScreen(this, service) }

    fun retire() {
        while (true) {
            val prior = ownership.value
            if (prior.retired) return
            if (ownership.compareAndSet(prior, prior.copy(retired = true))) {
                retireTransitions.incrementAndGet()
                prior.reservations.forEach { it.job.value?.cancel(CancellationException("Home route retired")) }
                return
            }
        }
    }

    private fun reserve(): Reservation? {
        while (true) {
            val prior = ownership.value
            if (prior.retired || prior.reservations.size >= maxJobs) {
                rejected.incrementAndGet()
                return null
            }
            val token = Reservation()
            val next = prior.copy(reservations = prior.reservations + token)
            if (ownership.compareAndSet(prior, next)) {
                accepted.incrementAndGet()
                recordMaximum(next.reservations.size)
                return token
            }
        }
    }

    private fun recordMaximum(value: Int) {
        while (true) {
            val old = maximum.value
            if (old >= value || maximum.compareAndSet(old, value)) return
        }
    }

    private fun forget(token: Reservation) {
        while (true) {
            val prior = ownership.value
            if (prior.reservations.none { it === token }) return
            if (ownership.compareAndSet(
                    prior,
                    prior.copy(reservations = prior.reservations.filterNot { it === token }),
                )
            ) {
                releases.incrementAndGet()
                return
            }
        }
    }

    private fun tryLaunch(
        scope: CoroutineScope,
        value: Int,
        loading: () -> Unit,
        publish: (HomeFeatureState) -> Unit,
    ): Boolean {
        val token = reserve() ?: return false
        var created: Job? = null
        return runCatching {
            val job =
                scope.launch(start = CoroutineStart.LAZY) {
                    try {
                        currentCoroutineContext().ensureActive()
                        val result = service.refresh(value)
                        if (!isOpen || !currentCoroutineContext().isActive) {
                            lateResultsRejected.incrementAndGet()
                            throw CancellationException("Retired result")
                        }
                        delivered.incrementAndGet()
                        publish(result)
                        publications.incrementAndGet()
                    } catch (
                        error: CancellationException,
                    ) {
                        cancelled.incrementAndGet()
                        throw error
                    } finally {
                        finished.incrementAndGet()
                    }
                }
            created = job
            // Install actual-completion cleanup before attaching/starting. Retire can
            // win either side of attachment; both paths keep the reservation until Job completion.
            job.invokeOnCompletion { forget(token) }
            token.job.value = job
            if (!isOpen) job.cancel(CancellationException("Retired before attach"))
            if (job.isActive || !job.isCancelled) {
                loading()
                job.start()
            }
            true
        }.onFailure {
            val job = created
            if (job == null) {
                forget(token)
            } else {
                job.invokeOnCompletion { forget(token) }
                job.cancel()
            }
        }.getOrThrow()
    }

    fun snapshot() =
        RouteMetrics(
            isOpen,
            isDrained,
            ownership.value.reservations.size,
            accepted.value,
            rejected.value,
            delivered.value,
            cancelled.value,
            finished.value,
            retireTransitions.value,
            lateResultsRejected.value,
            publications.value,
            releases.value,
            maximum.value,
        )

    @Composable private fun OwnedHomeScreen(
        owner: HomeRouteOwner,
        sharedService: HomeFeatureService,
    ) {
        var state by remember(sharedService) { mutableStateOf(sharedService.initialState()) }
        val scope = rememberCoroutineScope()
        HomeContent(state = state, onEvent = {
            if (owner.isOpen && state.counterLoadable !is CounterLoadable.Loading) {
                val previous = state.counterLoadable.currentValueForRefresh()
                owner.tryLaunch(scope, previous, { state = sharedService.loadingState(previous) }, { state = it })
            }
        })
    }
}

data class RouteMetrics(
    val open: Boolean,
    val drained: Boolean,
    val activeJobs: Int,
    val accepted: Int,
    val rejected: Int,
    val delivered: Int,
    val cancelled: Int,
    val finished: Int,
    val retireTransitions: Int,
    val lateResultsRejected: Int,
    val publications: Int,
    val releases: Int,
    val maximum: Int,
)
