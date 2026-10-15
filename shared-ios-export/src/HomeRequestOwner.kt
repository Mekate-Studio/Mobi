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
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.HomeFeatureState
import kotlin.coroutines.cancellation.CancellationException

class HomeRequestOwner(
    private val service: HomeFeatureService,
    private val maxJobs: Int,
    maxObserversPerRequest: Int,
) {
    init {
        require(maxJobs > 0)
        require(maxObserversPerRequest > 0)
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var retired = false
    private var nextId = 1L
    private val requests = mutableMapOf<Long, Request>()
    val completion = HomeRequestCompletion(maxObserversPerRequest) { requests[it]?.job }
    private var initialReads = 0
    private var loadingReads = 0
    private var accepted = 0
    private var delivered = 0
    private var cancelled = 0
    private var lateRejected = 0
    private var retireTransitions = 0

    private class Request {
        lateinit var job: Job
        var phase = HomeRequestPhase.Running // running, delivered, cancelled, unexpected bridge failure
        var value: HomeFeatureState? = null
    }

    private fun requireMain() {
        check(NSThread.isMainThread)
    }

    fun usesService(other: HomeFeatureService): Boolean {
        requireMain()
        return service === other
    }

    fun initialValue(): HomeFeatureState? {
        requireMain()
        if (retired) return null
        initialReads++
        return service.initialState()
    }

    fun loadingValue(current: Int): HomeFeatureState? {
        requireMain()
        if (retired) return null
        loadingReads++
        return service.loadingState(current)
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
                    if (retired || request.phase != HomeRequestPhase.Running ||
                        currentCoroutineContext()[Job]?.isActive != true
                    ) {
                        lateRejected++
                        throw CancellationException("Native result cancelled")
                    }
                    request.value = value
                    request.phase = HomeRequestPhase.Delivered
                    delivered++
                } catch (error: CancellationException) {
                    if (request.phase == HomeRequestPhase.Running) {
                        request.phase = HomeRequestPhase.Cancelled
                        cancelled++
                    }
                    throw error
                } catch (error: IllegalStateException) {
                    println("Mobi facade invariant failed: ${error.message}")
                    if (request.phase == HomeRequestPhase.Running) request.phase = HomeRequestPhase.BridgeFailure
                }
            }
        request.job.start()
        return id
    }

    fun poll(id: Long): HomeRequestSnapshot {
        requireMain()
        val request = checkNotNull(requests[id])
        return HomeRequestSnapshot(request.phase, request.job.isCompleted, request.value)
    }

    fun cancelRequest(id: Long) {
        requireMain()
        val request = requests[id] ?: return
        // A completed value can still be waiting for Swift to consume it.
        if (request.phase == HomeRequestPhase.Running || request.phase == HomeRequestPhase.Delivered) {
            request.phase = HomeRequestPhase.Cancelled
            request.value = null
            cancelled++
        }
        request.job.cancel(CancellationException("Native request cancelled"))
    }

    fun forgetRequest(id: Long): Boolean {
        requireMain()
        val request = requests[id]
        val completed = request == null || request.job.isCompleted
        if (completed) {
            completion.forget(id)
            requests.remove(id)
        }
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

    fun metrics(): HomeRequestMetrics {
        requireMain()
        return HomeRequestMetrics(
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

enum class HomeRequestPhase { Running, Delivered, Cancelled, BridgeFailure }

data class HomeRequestSnapshot(
    val phase: HomeRequestPhase,
    val drained: Boolean,
    val value: HomeFeatureState?,
)

data class HomeRequestMetrics(
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
