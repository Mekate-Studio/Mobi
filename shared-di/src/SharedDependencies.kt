package studio.mekate.b3.di

import dev.zacsweers.metro.DependencyGraph
import dev.zacsweers.metro.Provides
import dev.zacsweers.metro.createGraphFactory
import studio.mekate.b3.core.CounterRepository
import studio.mekate.b3.core.CounterRequestFailurePolicy
import studio.mekate.b3.core.FakeCounterRepository
import studio.mekate.b3.core.RandomCounterRequestFailurePolicy
import studio.mekate.b3.feature.home.HomeFeatureService

@DependencyGraph
interface SharedApplicationGraph {
    val counterRepository: CounterRepository
    val homeFeatureService: HomeFeatureService

    @DependencyGraph.Factory
    fun interface Factory {
        fun create(): SharedApplicationGraph
    }

    @Provides
    fun provideCounterRepository(
        repository: FakeCounterRepository,
    ): CounterRepository = repository

    @Provides
    fun provideCounterRequestFailurePolicy(
        policy: RandomCounterRequestFailurePolicy,
    ): CounterRequestFailurePolicy = policy
}

object SharedDependencies {
    fun createGraph(): SharedApplicationGraph {
        return createGraphFactory<SharedApplicationGraph.Factory>()
            .create()
    }

    fun createDefaultGraph(): SharedApplicationGraph {
        return createGraph()
    }

    fun createDefaultHomeFeatureService(): HomeFeatureService {
        return createDefaultGraph().homeFeatureService
    }
}
