@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package studio.mekate.mobi.nearbyvehiclemap

import androidx.compose.runtime.Composable
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
import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NearbyFleetRequest
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.di.SharedApplicationGraph
import studio.mekate.mobi.di.SharedDependencies
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.nativeTabContent
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

internal fun TestScope.queuedPresenter(repository: NearbyFleetRepository): Flow<NearbyVehicleMapScreenState> =
    nearbyTabContent(repository)

internal fun TestScope.nearbyTabContent(
    repository: NearbyFleetRepository,
    destination: State<AppDestination> = mutableStateOf(AppDestination.NearbyVehicleMap),
    owner: TabContentOwner? = null,
    locationEffects: @Composable (NearbyVehicleMapScreenState) -> Unit = {},
): Flow<NearbyVehicleMapScreenState> {
    val defaults = SharedDependencies.createDefaultGraph()
    val graph =
        object : SharedApplicationGraph by defaults {
            override val nearbyFleetRepository = repository
        }
    return nativeTabContent(destination, graph, owner, locationEffects)
        .filterIsInstance<NativeTabState.Nearby>()
        .map { it.state }
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
    val fleetRequests = mutableListOf<NearbyFleetRequest>()

    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
        val job = currentCoroutineContext().job
        jobs.add(job)
        fleetRequests.add(request)
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
