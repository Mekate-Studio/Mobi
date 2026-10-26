package studio.mekate.mobi.nearbyvehiclemap

import android.Manifest
import android.app.Application
import android.content.Context
import android.location.Location
import android.location.LocationManager
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.activity.result.ActivityResultRegistry
import androidx.activity.result.ActivityResultRegistryOwner
import androidx.activity.result.contract.ActivityResultContract
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalContext
import androidx.core.app.ActivityOptionsCompat
import androidx.lifecycle.Lifecycle
import app.cash.turbine.ReceiveTurbine
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import studio.mekate.mobi.TabContentOwner
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import app.cash.turbine.test as testFlow

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
@OptIn(ExperimentalCoroutinesApi::class)
class NearbyLocationLifecycleTest {
    @Test
    fun `should wait for first START and prompt once without repeating after denial`() =
        runTest {
            // given
            val fixture = LocationFixture()
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner(Lifecycle.State.CREATED)
            platformContent(repository, owner, fixture).testFlow {
                awaitItem()
                runCurrent()
                assertTrue(fixture.permissions.launches.isEmpty())
                assertTrue(repository.requests.tryReceive().isFailure)

                // when
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                nextState { it.riderLocationState == RiderLocationState.Denied }
                runCurrent()
                fixture.permissions.complete(granted = false)
                runCurrent()

                // then
                expectNoEvents()
                assertEquals(1, fixture.permissions.launches.size)
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                runCurrent()
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                runCurrent()
                expectNoEvents()
                assertEquals(1, fixture.permissions.launches.size)
                assertTrue(repository.requests.tryReceive().isFailure)
                cancelAndIgnoreRemainingEvents()
            }
        }

    @Test
    fun `should recheck current permissions instead of trusting callback payload`() =
        runTest {
            for (payloadGranted in listOf(false, true)) {
                // given
                val fixture = LocationFixture()
                val repository = ControlledFleetRepository()
                val owner = TabContentOwner()
                platformContent(repository, owner, fixture).testFlow {
                    nextState { it.riderLocationState == RiderLocationState.Denied }
                    runCurrent()
                    if (!payloadGranted) fixture.allowPreciseLocation(RIDER_LOCATION)

                    // when: Android state contradicts the result payload.
                    fixture.permissions.complete(granted = payloadGranted)
                    runCurrent()

                    // then
                    if (payloadGranted) {
                        expectNoEvents()
                        assertTrue(repository.requests.tryReceive().isFailure)
                    } else {
                        nextState { it.snapshotState is NearbyVehicleSnapshotState.Loading }
                        repository.requests.receive().complete(Result.success(snapshot(1)))
                        assertIs<NearbyVehicleSnapshotState.Loaded>(
                            nextState { it.canRequestRefresh() }.featureState.snapshotState,
                        )
                        assertEquals(RIDER_LOCATION, repository.fleetRequests.single().riderLocation)
                    }
                    cancelAndIgnoreRemainingEvents()
                }
            }
        }

    @Test
    fun `should defer stopped permission callbacks until START and use current location on each return`() =
        runTest {
            // given
            val fixture = LocationFixture()
            val repository = ControlledFleetRepository()
            val owner = TabContentOwner()
            platformContent(repository, owner, fixture).testFlow {
                nextState { it.riderLocationState == RiderLocationState.Denied }
                runCurrent()
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                runCurrent()
                fixture.allowPreciseLocation(RIDER_LOCATION)

                // when
                fixture.permissions.complete(granted = true)
                runCurrent()

                // then
                expectNoEvents()
                assertTrue(repository.requests.tryReceive().isFailure)
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                nextState { it.snapshotState is NearbyVehicleSnapshotState.Loading }
                repository.requests.receive().complete(Result.success(snapshot(1)))
                val loaded = nextState { it.snapshotState is NearbyVehicleSnapshotState.Loaded }
                owner.lifecycle.currentState = Lifecycle.State.RESUMED
                runCurrent()
                expectNoEvents()
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                fixture.denyLocation()
                runCurrent()
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                val blocked = nextState { it.riderLocationState == RiderLocationState.Denied }
                assertFalse(blocked.featureState.canRequestRefresh())
                assertEquals(
                    assertIs<NearbyVehicleSnapshotState.Loaded>(loaded.featureState.snapshotState).snapshot,
                    assertIs<NearbyVehicleSnapshotState.FailedWithSnapshot>(
                        blocked.featureState.snapshotState,
                    ).snapshot,
                )
                assertTrue(repository.requests.tryReceive().isFailure)
                assertEquals(1, fixture.permissions.launches.size)
                val moved = RiderLocation(latitude = 55.68, longitude = 12.57)
                owner.lifecycle.currentState = Lifecycle.State.CREATED
                fixture.allowPreciseLocation(moved)
                runCurrent()
                owner.lifecycle.currentState = Lifecycle.State.STARTED
                nextState { it.snapshotState is NearbyVehicleSnapshotState.Refreshing }
                repository.requests.receive().complete(Result.success(snapshot(2, location = moved)))
                val returned = nextState { it.snapshotState is NearbyVehicleSnapshotState.Loaded }
                assertEquals(RiderLocationState.Available(moved), returned.featureState.riderLocationState)
                assertEquals(listOf(RIDER_LOCATION, moved), repository.fleetRequests.map { it.riderLocation })
                cancelAndIgnoreRemainingEvents()
            }
        }
}

private class LocationFixture {
    val context: Application = RuntimeEnvironment.getApplication()
    val permissions = PermissionRegistry()

    init {
        denyLocation()
    }

    fun denyLocation() {
        shadowOf(
            context,
        ).denyPermissions(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    fun allowPreciseLocation(point: RiderLocation) {
        shadowOf(
            context,
        ).grantPermissions(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        shadowOf(manager).setProviderEnabled(LocationManager.GPS_PROVIDER, true)
        shadowOf(manager).simulateLocation(
            Location(LocationManager.GPS_PROVIDER).apply {
                latitude = point.latitude
                longitude = point.longitude
            },
        )
    }
}

private class PermissionRegistry :
    ActivityResultRegistry(),
    ActivityResultRegistryOwner {
    override val activityResultRegistry: ActivityResultRegistry get() = this
    val launches = mutableListOf<Int>()

    override fun <I, O> onLaunch(
        requestCode: Int,
        contract: ActivityResultContract<I, O>,
        input: I,
        options: ActivityOptionsCompat?,
    ) {
        launches += requestCode
    }

    fun complete(granted: Boolean) {
        dispatchResult(
            launches.last(),
            mapOf(
                Manifest.permission.ACCESS_FINE_LOCATION to granted,
                Manifest.permission.ACCESS_COARSE_LOCATION to granted,
            ),
        )
    }
}

private fun TestScope.platformContent(
    repository: ControlledFleetRepository,
    owner: TabContentOwner,
    fixture: LocationFixture,
): Flow<NearbyVehicleMapScreenState> =
    nearbyTabContent(repository, owner = owner, locationEffects = { state ->
        CompositionLocalProvider(
            LocalContext provides fixture.context,
            LocalActivityResultRegistryOwner provides fixture.permissions,
        ) {
            NearbyVehicleLocationEffects(state)
        }
    })

private suspend fun ReceiveTurbine<NearbyVehicleMapScreenState>.nextState(
    predicate: (NearbyVehicleMapFeatureState) -> Boolean,
): NearbyVehicleMapScreenState {
    while (true) {
        val state = awaitItem()
        if (predicate(state.featureState)) return state
    }
}
