@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package studio.mekate.mobi.export.home

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.launch
import platform.Foundation.NSThread
import studio.mekate.mobi.feature.home.CounterLoadFailureReason
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.HomeFeatureState
import kotlin.coroutines.cancellation.CancellationException

class HomeFacade(
    private val service: HomeFeatureService,
    private val maxJobs: Int,
) {
    init {
        require(maxJobs > 0)
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var retired = false
    private var nextId = 1L
    private val requests = mutableMapOf<Long, Request>()
    private var initialReads = 0
    private var loadingReads = 0
    private var accepted = 0
    private var delivered = 0
    private var cancelled = 0
    private var lateRejected = 0
    private var retireTransitions = 0

    private class Request {
        lateinit var job: Job
        var phase = 0 // running, delivered, cancelled, unexpected bridge failure
        var value: NativeHomeSnapshot? = null
    }

    private fun requireMain() {
        check(NSThread.isMainThread)
    }

    fun usesService(other: HomeFeatureService): Boolean {
        requireMain()
        return service === other
    }

    fun initialValue(): NativeHomeSnapshot? {
        requireMain()
        if (retired) return null
        initialReads++
        return nativeValue(service.initialState())
    }

    fun loadingValue(current: Int): NativeHomeSnapshot? {
        requireMain()
        if (retired) return null
        loadingReads++
        return nativeValue(service.loadingState(current))
    }

    fun beginRefresh(current: Int): Long {
        requireMain()
        if (retired || requests.values.count { !it.job.isCompleted } >= maxJobs) return 0
        val id = nextId++
        val request = Request()
        requests[id] = request
        accepted++
        request.job =
            scope.launch(start = CoroutineStart.LAZY) {
                try {
                    val value = service.refresh(current)
                    requireMain()
                    if (retired || request.phase != 0 || currentCoroutineContext()[Job]?.isActive != true) {
                        lateRejected++
                        throw CancellationException("Native result cancelled")
                    }
                    request.value = nativeValue(value)
                    request.phase = 1
                    delivered++
                } catch (error: CancellationException) {
                    if (request.phase == 0) {
                        request.phase = 2
                        cancelled++
                    }
                    throw error
                } catch (error: IllegalStateException) {
                    println("Mobi facade invariant failed: ${error.message}")
                    if (request.phase == 0) request.phase = 3
                }
            }
        request.job.start()
        return id
    }

    fun poll(id: Long): NativeRequestSnapshot {
        requireMain()
        val request = checkNotNull(requests[id])
        return NativeRequestSnapshot(request.phase, request.job.isCompleted, request.value)
    }

    fun cancelRequest(id: Long) {
        requireMain()
        val request = requests[id] ?: return
        // A completed value can still be waiting for Swift to consume it.
        if (request.phase == 0 || request.phase == 1) {
            request.phase = 2
            request.value = null
            cancelled++
        }
        request.job.cancel(CancellationException("Native request cancelled"))
    }

    fun forgetRequest(id: Long): Boolean {
        requireMain()
        val request = requests[id]
        val completed = request == null || request.job.isCompleted
        if (completed) requests.remove(id)
        return completed
    }

    fun retire() {
        requireMain()
        if (retired) return
        retired = true
        retireTransitions++
        requests.keys.toList().forEach { cancelRequest(it) }
        scope.coroutineContext[Job]?.cancel()
    }

    fun metrics(): FacadeMetrics {
        requireMain()
        return FacadeMetrics(
            retired,
            requests.values.count { !it.job.isCompleted },
            requests.size,
            accepted,
            delivered,
            cancelled,
            lateRejected,
            retireTransitions,
            initialReads,
            loadingReads,
        )
    }
}

// Version-1 wire algebra. Swift copies these into checked Sendable enums
// synchronously on the main actor; Kotlin wrappers never become async return values.
data class NativeHomeSnapshot(
    val tag: Int,
    val value: Int?,
    val reason: Int?,
)

data class NativeRequestSnapshot(
    val phase: Int,
    val drained: Boolean,
    val value: NativeHomeSnapshot?,
)

data class FacadeMetrics(
    val retired: Boolean,
    val active: Int,
    val retained: Int,
    val accepted: Int,
    val delivered: Int,
    val cancelled: Int,
    val lateRejected: Int,
    val retireTransitions: Int,
    val initialReads: Int,
    val loadingReads: Int,
)

private fun nativeValue(state: HomeFeatureState): NativeHomeSnapshot =
    when (val loadable = state.counterLoadable) {
        CounterLoadable.Initial -> {
            NativeHomeSnapshot(0, null, null)
        }

        is CounterLoadable.Loading -> {
            NativeHomeSnapshot(1, loadable.previousValue, null)
        }

        is CounterLoadable.Loaded -> {
            NativeHomeSnapshot(2, loadable.value, null)
        }

        is CounterLoadable.Error -> {
            NativeHomeSnapshot(
                3,
                loadable.previousValue,
                when (loadable.reason) {
                    CounterLoadFailureReason.RepositoryUnavailable -> 0
                    CounterLoadFailureReason.Unexpected -> 1
                },
            )
        }
    }
