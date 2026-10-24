@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package studio.mekate.mobi.nearbyvehiclemap

import app.cash.molecule.RecompositionMode
import app.cash.molecule.moleculeFlow
import app.cash.turbine.ReceiveTurbine
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.job
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.withContext
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFreshnessPolicy
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import kotlin.test.assertIs

internal suspend fun ReceiveTurbine<NearbyVehicleMapScreenState>.startRefresh(
    repository: ControlledFleetRepository,
    hasSnapshot: Boolean,
): NearbyVehicleMapScreenState {
    if (hasSnapshot) {
        resolveLocation(repository).eventSink(NearbyVehicleMapScreenEvent.ManualRefreshRequested(nowMillis = 0))
    } else {
        awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
    }
    return awaitItem().also { loading ->
        if (hasSnapshot) {
            assertIs<NearbyVehicleSnapshotState.Refreshing>(loading.featureState.snapshotState)
        } else {
            assertIs<NearbyVehicleSnapshotState.Loading>(loading.featureState.snapshotState)
        }
    }
}

internal fun TestScope.queuedPresenter(repository: NearbyFleetRepository): Flow<NearbyVehicleMapScreenState> {
    val presenter = presenter(repository)
    // Queue presenter launches so Turbine's eager collector cannot hide admission races.
    return moleculeFlow(RecompositionMode.Immediate) { presenter.present() }
        .flowOn(StandardTestDispatcher(testScheduler))
}

internal suspend fun ReceiveTurbine<NearbyVehicleMapScreenState>.resolveLocation(
    repository: ControlledFleetRepository,
    loadedAtMillis: Long = 0,
): NearbyVehicleMapScreenState = resolveLocation(repository.requests, loadedAtMillis)

internal suspend fun ReceiveTurbine<NearbyVehicleMapScreenState>.resolveLocation(
    requests: Channel<CompletableDeferred<Result<FleetSnapshot>>>,
    loadedAtMillis: Long = 0,
): NearbyVehicleMapScreenState {
    awaitItem().eventSink(NearbyVehicleMapScreenEvent.PreciseLocationResolved(RIDER_LOCATION))
    assertIs<NearbyVehicleSnapshotState.Loading>(awaitItem().featureState.snapshotState)
    requests.receive().complete(Result.success(snapshot(sequence = 1, loadedAtMillis = loadedAtMillis)))
    return awaitItem().also { assertIs<NearbyVehicleSnapshotState.Loaded>(it.featureState.snapshotState) }
}

internal fun presenter(repository: NearbyFleetRepository) =
    NearbyVehicleMapPresenter(
        NearbyVehicleMapFeatureService(repository, NearbyVehicleMapFreshnessPolicy()),
    )

internal fun snapshot(
    sequence: Long,
    loadedAtMillis: Long = 0,
    location: RiderLocation = RIDER_LOCATION,
) = FleetSnapshot(
    sequence = sequence,
    riderLocation = location,
    vehicles = emptyList(),
    loadedAtMillis = loadedAtMillis,
)

internal val RIDER_LOCATION = RiderLocation(latitude = 55.6761, longitude = 12.5683)
internal const val REFRESH_INTERVAL_MILLIS = NearbyVehicleMapFeatureService.REFRESH_INTERVAL_MILLIS

internal class ControlledFleetRepository : NearbyFleetRepository {
    val requests = Channel<CompletableDeferred<Result<FleetSnapshot>>>(Channel.UNLIMITED)
    val jobs = mutableListOf<Job>()

    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
        val job = currentCoroutineContext().job
        jobs.add(job)
        val result = CompletableDeferred<Result<FleetSnapshot>>(job)
        requests.send(result)
        // Throw from the repository; failing the deferred child would cancel its parent job.
        return result.await().getOrThrow()
    }
}

internal class LateCompletingFleetRepository : NearbyFleetRepository {
    val requests = Channel<CompletableDeferred<Result<FleetSnapshot>>>(Channel.UNLIMITED)
    private val pending = mutableListOf<CompletableDeferred<Result<FleetSnapshot>>>()

    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot =
        // Simulate a callback-backed provider returning after its caller was cancelled.
        withContext(NonCancellable) {
            val result = CompletableDeferred<Result<FleetSnapshot>>()
            pending.add(result)
            requests.send(result)
            result.await().getOrThrow()
        }

    fun completePendingRequests() {
        pending.forEach { it.complete(Result.failure(CancellationException())) }
    }
}
