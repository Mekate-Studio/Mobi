package studio.mekate.mobi.export.nearby

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.launch
import platform.Foundation.NSThread
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.export.request.RequestCompletion
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.canInteractWithVehicles
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import kotlin.coroutines.cancellation.CancellationException

private fun mainOnly() {
    check(NSThread.isMainThread)
}

// Immutable states remain original Kotlin values. Handles belong to this facade only.
// Swift additionally verifies an owner UUID before making any raw call.
class NearbyValueOwner(
    private val service: NearbyVehicleMapFeatureService,
) {
    private var retired = false
    private var nextState = 1L
    private val states = mutableMapOf<Long, NearbyVehicleMapFeatureState>()
    internal val count: Int get() = states.size

    internal fun state(id: Long): NearbyVehicleMapFeatureState {
        mainOnly()
        check(!retired)
        return checkNotNull(states[id])
    }

    internal fun store(state: NearbyVehicleMapFeatureState): NearbyOwnedValue {
        mainOnly()
        check(!retired)
        val id = nextState++
        states[id] =
            state
        return NearbyOwnedValue(id, state)
    }

    fun initialValue(): NearbyOwnedValue = store(service.initialState())

    fun available(
        id: Long,
        latitude: Double,
        longitude: Double,
    ): NearbyOwnedValue = store(service.riderLocationAvailable(state(id), RiderLocation(latitude, longitude)))

    fun blocked(
        id: Long,
        reason: RiderLocationBlockedReason,
    ): NearbyOwnedValue = store(service.riderLocationBlocked(state(id), reason))

    fun loading(id: Long): NearbyOwnedValue = store(service.loadingState(state(id)))

    fun timePassed(
        id: Long,
        now: Long,
    ): NearbyOwnedValue = store(service.stateAfterTimePasses(state(id), now))

    fun hasState(id: Long): Boolean {
        mainOnly()
        return !retired && states.containsKey(id)
    }

    fun releaseState(id: Long) {
        mainOnly()
        states.remove(id)
    }

    internal fun retire() {
        mainOnly()
        retired = true
        states.clear()
    }
}

class NearbyRequestOwner(
    private val service: NearbyVehicleMapFeatureService,
    private val maxJobs: Int,
    maxObserversPerRequest: Int,
) {
    init {
        require(maxJobs > 0)
        require(maxObserversPerRequest > 0)
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var retired = false
    private var nextRequest = 1L
    val states = NearbyValueOwner(service)

    private class Request {
        lateinit var job: Job
        var phase = NearbyRequestPhase.Running
        var value: NearbyVehicleMapFeatureState? = null
    }

    private val requests = mutableMapOf<Long, Request>()
    val completion = RequestCompletion(maxObserversPerRequest) { requests[it]?.job }
    private var accepted = 0
    private var delivered = 0
    private var cancelled = 0
    private var lateRejected = 0

    fun temporary(id: Long): NearbyOwnedValue =
        states.store(service.riderLocationTemporarilyUnavailable(states.state(id)))

    fun shouldRefresh(
        id: Long,
        now: Long,
    ): Boolean = service.shouldRefresh(states.state(id), now)

    fun beginRefresh(
        id: Long,
        now: Long,
    ): Long {
        mainOnly()
        if (retired || requests.values.count { !it.job.isCompleted } >= maxJobs) return 0
        val current = states.state(id) // immutable captured state survives explicit handle release
        val requestId = nextRequest++
        val request = Request()
        requests[requestId] = request
        accepted++
        request.job =
            scope.launch(start = CoroutineStart.LAZY) {
                try {
                    val result = service.refreshSnapshot(current, now)
                    mainOnly()
                    if (retired || request.phase != NearbyRequestPhase.Running ||
                        currentCoroutineContext()[Job]?.isActive != true
                    ) {
                        lateRejected++
                        throw CancellationException("Late Nearby result")
                    }
                    request.value = result
                    request.phase = NearbyRequestPhase.Delivered
                    delivered++
                } catch (error: CancellationException) {
                    if (request.phase == NearbyRequestPhase.Running) {
                        request.phase = NearbyRequestPhase.Cancelled
                        cancelled++
                    }
                    throw error
                } catch (error: IllegalStateException) {
                    println("Mobi facade invariant failed: ${error.message}")
                    if (request.phase == NearbyRequestPhase.Running) request.phase = NearbyRequestPhase.BridgeFailure
                }
            }
        request.job.start()
        return requestId
    }

    fun poll(id: Long): NearbyRequestSnapshot {
        mainOnly()
        val r = checkNotNull(requests[id])
        return NearbyRequestSnapshot(r.phase, r.job.isCompleted)
    }

    fun consume(id: Long): NearbyOwnedValue {
        mainOnly()
        val r = checkNotNull(requests[id])
        check(r.phase == NearbyRequestPhase.Delivered && r.job.isCompleted && !retired)
        val result = states.store(checkNotNull(r.value))
        completion.forget(id)
        requests.remove(id)
        return result
    }

    fun cancelRequest(id: Long) {
        mainOnly()
        val r =
            requests[id] ?: return
        if (r.phase == NearbyRequestPhase.Running ||
            r.phase == NearbyRequestPhase.Delivered
        ) {
            r.phase = NearbyRequestPhase.Cancelled
            r.value = null
            cancelled++
        }
        r.job.cancel()
    }

    fun forgetRequest(id: Long): Boolean {
        mainOnly()
        val request = requests[id]
        val completed = request == null || request.job.isCompleted
        if (completed) {
            completion.forget(id)
            requests.remove(id)
        }
        return completed
    }

    fun retire() {
        mainOnly()
        if (retired) return
        retired = true
        states.retire()
        requests.keys.toList().forEach { cancelRequest(it) }
        scope.cancel()
    }

    fun metrics(): NearbyRequestMetrics {
        mainOnly()
        return NearbyRequestMetrics(
            retired,
            states.count,
            requests.size,
            requests.values.count {
                !it.job.isCompleted
            },
            accepted,
            delivered,
            cancelled,
            lateRejected,
        )
    }
}

data class NearbyRequestSnapshot(
    val phase: NearbyRequestPhase,
    val drained: Boolean,
)

data class NearbyRequestMetrics(
    val retired: Boolean,
    val states: Int,
    val requests: Int,
    val active: Int,
    val accepted: Int,
    val delivered: Int,
    val cancelled: Int,
    val lateRejected: Int,
)

enum class NearbyRequestPhase { Running, Delivered, Cancelled, BridgeFailure }

// This carries the original typed state. It defines no parallel feature tags.
class NearbyOwnedValue(
    val id: Long,
    val value: NearbyVehicleMapFeatureState,
) {
    val canRefresh: Boolean get() = value.canRequestRefresh()
    val canInteract: Boolean get() = value.canInteractWithVehicles()
}
