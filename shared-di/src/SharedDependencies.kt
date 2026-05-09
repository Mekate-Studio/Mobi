package studio.mekate.mobi.di

import dev.zacsweers.metro.DependencyGraph
import dev.zacsweers.metro.Provides
import dev.zacsweers.metro.createGraphFactory
import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.core.CounterRequestFailurePolicy
import studio.mekate.mobi.core.FakeCounterRepository
import studio.mekate.mobi.core.NearbyFleetFailurePolicy
import studio.mekate.mobi.core.NearbyFleetRepository
import studio.mekate.mobi.core.NeverFailNearbyFleetFailurePolicy
import studio.mekate.mobi.core.RandomCounterRequestFailurePolicy
import studio.mekate.mobi.core.SimulatedNearbyFleetRepository
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService

@DependencyGraph
interface SharedApplicationGraph {
    val counterRepository: CounterRepository
    val homeFeatureService: HomeFeatureService
    val nearbyFleetRepository: NearbyFleetRepository
    val nearbyVehicleMapFeatureService: NearbyVehicleMapFeatureService

    @DependencyGraph.Factory
    fun interface Factory {
        fun create(): SharedApplicationGraph
    }

    @Provides
    fun provideCounterRepository(repository: FakeCounterRepository): CounterRepository = repository

    @Provides
    fun provideNearbyFleetRepository(repository: SimulatedNearbyFleetRepository): NearbyFleetRepository = repository

    @Provides
    fun provideCounterRequestFailurePolicy(policy: RandomCounterRequestFailurePolicy): CounterRequestFailurePolicy =
        policy

    @Provides
    fun provideNearbyFleetFailurePolicy(policy: NeverFailNearbyFleetFailurePolicy): NearbyFleetFailurePolicy = policy
}

object SharedDependencies {
    fun createGraph(): SharedApplicationGraph =
        createGraphFactory<SharedApplicationGraph.Factory>()
            .create()

    fun createDefaultGraph(): SharedApplicationGraph = createGraph()

    fun createDefaultHomeFeatureService(): HomeFeatureService = createDefaultGraph().homeFeatureService

    fun createDefaultNearbyVehicleMapFeatureService(): NearbyVehicleMapFeatureService =
        createDefaultGraph().nearbyVehicleMapFeatureService
}
