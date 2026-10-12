package studio.mekate.mobi.export.nearby

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import platform.Foundation.NSThread
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.FailedNearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFailureReason
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFreshnessPolicy
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.SnapshotBackedNearbyVehicleState
import studio.mekate.mobi.feature.nearbyvehiclemap.VisibleRiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canInteractWithVehicles
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import kotlin.coroutines.cancellation.CancellationException

private fun mainOnly() {
    check(NSThread.isMainThread)
}

// One exact repository instance and one policy shared by all Nearby owners.
// Main confinement allows suspended operations to overlap. It is not serialization.
class NearbyHub(
    private val delegate: NearbyFleetRepository,
    val policy: Int,
    private val maxJobsPerOwner: Int,
) {
    private val mutex = Mutex()
    private var entered = 0
    private var active = 0
    private var maxActive = 0
    private var returned = 0
    private val repository =
        object : NearbyFleetRepository {
            override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
                suspend fun operation(): FleetSnapshot {
                    if (policy == 0) mainOnly()
                    withContext(Dispatchers.Main.immediate) {
                        entered++
                        active++
                        maxActive = maxOf(maxActive, active)
                    }
                    try {
                        val snapshot = delegate.fetchNearbyFleetSnapshot(request)
                        withContext(Dispatchers.Main.immediate) { returned++ }
                        return snapshot
                    } finally {
                        if (policy == 0) mainOnly()
                        withContext(NonCancellable + Dispatchers.Main.immediate) { active-- }
                    }
                }
                return if (policy ==
                    0
                ) {
                    operation()
                } else {
                    withContext(Dispatchers.Default) { mutex.withLock { operation() } }
                }
            }
        }
    private val service = NearbyVehicleMapFeatureService(repository, NearbyVehicleMapFreshnessPolicy())

    init {
        mainOnly()
        require(policy == 0 || policy == 1)
        require(maxJobsPerOwner > 0)
    }

    fun makeFacade(): NearbyFacade {
        mainOnly()
        return NearbyFacade(service, maxJobsPerOwner)
    }

    fun metrics(): RepositoryMetrics {
        mainOnly()
        return RepositoryMetrics(entered, active, maxActive, returned)
    }
}

data class RepositoryMetrics(
    val entered: Int,
    val active: Int,
    val maxActive: Int,
    val returned: Int,
)

// Immutable states remain original Kotlin values. Handles belong to this facade only.
// Swift additionally verifies an owner UUID before making any raw call.
class NearbyStateOwner(
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

    internal fun store(state: NearbyVehicleMapFeatureState): WireState {
        mainOnly()
        check(!retired)
        val id = nextState++
        states[id] =
            state
        return WireState(id, state)
    }

    fun initialValue(): WireState = store(service.initialState())

    fun available(
        id: Long,
        latitude: Double,
        longitude: Double,
    ): WireState = store(service.riderLocationAvailable(state(id), RiderLocation(latitude, longitude)))

    fun blocked(
        id: Long,
        reason: Int,
    ): WireState = store(service.riderLocationBlocked(state(id), decodeBlocked(reason)))

    fun loading(id: Long): WireState = store(service.loadingState(state(id)))

    fun timePassed(
        id: Long,
        now: Long,
    ): WireState = store(service.stateAfterTimePasses(state(id), now))

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

class NearbyFacade(
    private val service: NearbyVehicleMapFeatureService,
    private val maxJobs: Int,
) {
    init {
        require(maxJobs > 0)
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var retired = false
    private var nextRequest = 1L
    val states = NearbyStateOwner(service)

    private class Request {
        lateinit var job: Job
        var phase = 0
        var value: NearbyVehicleMapFeatureState? = null
    }

    private val requests = mutableMapOf<Long, Request>()
    private var accepted = 0
    private var delivered = 0
    private var cancelled = 0
    private var lateRejected = 0

    fun temporary(id: Long): WireState = states.store(service.riderLocationTemporarilyUnavailable(states.state(id)))

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
                    if (retired || request.phase != 0 || currentCoroutineContext()[Job]?.isActive != true) {
                        lateRejected++
                        throw CancellationException("Late Nearby result")
                    }
                    request.value = result
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
        return requestId
    }

    fun poll(id: Long): WireRequest {
        mainOnly()
        val r = checkNotNull(requests[id])
        return WireRequest(r.phase, r.job.isCompleted)
    }

    fun consume(id: Long): WireState {
        mainOnly()
        val r = checkNotNull(requests[id])
        check(r.phase == 1 && r.job.isCompleted && !retired)
        val result = states.store(checkNotNull(r.value))
        requests.remove(id)
        return result
    }

    fun cancelRequest(id: Long) {
        mainOnly()
        val r =
            requests[id] ?: return
        if (r.phase == 0 ||
            r.phase == 1
        ) {
            r.phase = 2
            r.value = null
            cancelled++
        }
        r.job.cancel()
    }

    fun forgetRequest(id: Long): Boolean {
        mainOnly()
        val request = requests[id]
        val completed = request == null || request.job.isCompleted
        if (completed) requests.remove(id)
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

    fun metrics(): FacadeMetrics {
        mainOnly()
        return FacadeMetrics(
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

data class WireRequest(
    val phase: Int,
    val drained: Boolean,
)

data class FacadeMetrics(
    val retired: Boolean,
    val states: Int,
    val requests: Int,
    val active: Int,
    val accepted: Int,
    val delivered: Int,
    val cancelled: Int,
    val lateRejected: Int,
)

data class WireVehicle(
    val id: String,
    val latitude: Double,
    val longitude: Double,
)

// Wire tags are transport only; the source feature service owns transitions/freshness.
class WireState(
    val id: Long,
    private val state: NearbyVehicleMapFeatureState,
) {
    val schemaVersion = 1
    private val location = (state.riderLocationState as? VisibleRiderLocationState)?.location
    private val snapshot = (state.snapshotState as? SnapshotBackedNearbyVehicleState)?.snapshot
    val locationTag =
        when (state.riderLocationState) {
            RiderLocationState.Resolving -> 0
            is RiderLocationState.Available -> 1
            RiderLocationState.Denied -> 2
            is RiderLocationState.Blocked -> 3
            is RiderLocationState.TemporarilyUnavailable -> 4
            RiderLocationState.Unavailable -> 5
        }
    val latitude = location?.latitude
    val longitude = location?.longitude
    val blockedReason = (state.riderLocationState as? RiderLocationState.Blocked)?.reason?.let(::blockedTag)
    val snapshotTag =
        when (state.snapshotState) {
            NearbyVehicleSnapshotState.Initial -> 0
            NearbyVehicleSnapshotState.Loading -> 1
            is NearbyVehicleSnapshotState.Loaded -> 2
            is NearbyVehicleSnapshotState.Refreshing -> 3
            is NearbyVehicleSnapshotState.FailedWithSnapshot -> 4
            is NearbyVehicleSnapshotState.FailedWithoutSnapshot -> 5
        }
    val failureReason = (state.snapshotState as? FailedNearbyVehicleSnapshotState)?.reason?.let(::failureTag)
    val sequence = snapshot?.sequence
    val loadedAt = snapshot?.loadedAtMillis
    val snapshotLatitude = snapshot?.riderLocation?.latitude
    val snapshotLongitude = snapshot?.riderLocation?.longitude
    val vehicleCount = snapshot?.vehicles?.size ?: 0
    val overlayTag =
        when (state.mapOverlayState) {
            NearbyVehicleMapOverlayState.None -> 0
            NearbyVehicleMapOverlayState.RefreshingIndicator -> 1
            NearbyVehicleMapOverlayState.StaleIndicator -> 2
            NearbyVehicleMapOverlayState.BlockingFailure -> 3
        }
    val canRefresh = state.canRequestRefresh()
    val canInteract = state.canInteractWithVehicles()

    fun vehicleAt(index: Int): WireVehicle {
        val v = checkNotNull(snapshot).vehicles[index]
        return WireVehicle(v.id.value, v.location.latitude, v.location.longitude)
    }
}

private fun blockedTag(reason: RiderLocationBlockedReason): Int =
    when (reason) {
        RiderLocationBlockedReason.AccessDenied -> 0
        RiderLocationBlockedReason.AccessRestricted -> 1
        RiderLocationBlockedReason.ServicesDisabled -> 2
        RiderLocationBlockedReason.ApproximateOnly -> 3
        RiderLocationBlockedReason.TemporarilyUnavailable -> 4
    }

private fun decodeBlocked(tag: Int): RiderLocationBlockedReason =
    when (tag) {
        0 -> RiderLocationBlockedReason.AccessDenied
        1 -> RiderLocationBlockedReason.AccessRestricted
        2 -> RiderLocationBlockedReason.ServicesDisabled
        3 -> RiderLocationBlockedReason.ApproximateOnly
        4 -> RiderLocationBlockedReason.TemporarilyUnavailable
        else -> error("Invalid blocked tag")
    }

private fun failureTag(reason: NearbyVehicleMapFailureReason): Int =
    when (reason) {
        NearbyVehicleMapFailureReason.RiderLocationUnavailable -> 0
        NearbyVehicleMapFailureReason.RepositoryUnavailable -> 1
        NearbyVehicleMapFailureReason.Unexpected -> 2
    }
