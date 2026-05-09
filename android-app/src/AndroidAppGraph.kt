package studio.mekate.mobi

import com.slack.circuit.foundation.Circuit
import dev.zacsweers.metro.DependencyGraph
import dev.zacsweers.metro.Provides
import dev.zacsweers.metro.createGraphFactory
import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.di.SharedApplicationGraph
import studio.mekate.mobi.home.HomePresenterFactory
import studio.mekate.mobi.home.HomeUiFactory
import studio.mekate.mobi.nearbyvehiclemap.NearbyVehicleMapPresenterFactory
import studio.mekate.mobi.nearbyvehiclemap.NearbyVehicleMapUiFactory

@DependencyGraph
interface AndroidAppGraph {
    val circuit: Circuit

    @DependencyGraph.Factory
    fun interface Factory {
        fun create(
            @Provides sharedApplicationGraph: SharedApplicationGraph,
        ): AndroidAppGraph
    }

    @Provides
    fun provideCounterRepository(sharedApplicationGraph: SharedApplicationGraph): CounterRepository =
        sharedApplicationGraph.counterRepository

    @Provides
    fun provideNearbyFleetRepository(sharedApplicationGraph: SharedApplicationGraph): NearbyFleetRepository =
        sharedApplicationGraph.nearbyFleetRepository

    @Provides
    fun provideCircuit(
        homePresenterFactory: HomePresenterFactory,
        homeUiFactory: HomeUiFactory,
        nearbyVehicleMapPresenterFactory: NearbyVehicleMapPresenterFactory,
        nearbyVehicleMapUiFactory: NearbyVehicleMapUiFactory,
    ): Circuit =
        Circuit
            .Builder()
            .addPresenterFactory(homePresenterFactory)
            .addUiFactory(homeUiFactory)
            .addPresenterFactory(nearbyVehicleMapPresenterFactory)
            .addUiFactory(nearbyVehicleMapUiFactory)
            .build()
}

object AndroidDependencies {
    fun createGraph(sharedApplicationGraph: SharedApplicationGraph): AndroidAppGraph =
        createGraphFactory<AndroidAppGraph.Factory>()
            .create(sharedApplicationGraph)
}
