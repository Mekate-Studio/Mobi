package studio.mekate.mobi.di

import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import kotlin.test.Test
import kotlin.test.assertIs

class SharedDependenciesTest {
    @Test
    fun `should create home feature service from default graph`() {
        // given
        val service = SharedDependencies.createDefaultHomeFeatureService()

        // when
        val state = service.initialState()

        // then
        assertIs<CounterLoadable.Initial>(state.counterLoadable)
    }

    @Test
    fun `should create nearby vehicle map feature service from default graph`() {
        // given
        val service = SharedDependencies.createDefaultNearbyVehicleMapFeatureService()

        // when
        val state = service.initialState()

        // then
        assertIs<NearbyVehicleSnapshotState.Initial>(state.snapshotState)
    }
}
