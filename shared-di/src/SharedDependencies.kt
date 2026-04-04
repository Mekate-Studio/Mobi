package studio.mekate.b3.di

import dev.zacsweers.metro.DependencyGraph
import dev.zacsweers.metro.Provides
import dev.zacsweers.metro.createGraphFactory
import studio.mekate.b3.core.CounterRepository
import studio.mekate.b3.core.FakeCounterRepository
import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.core.platformName
import studio.mekate.b3.feature.home.HomeFeatureService

@DependencyGraph
interface SharedApplicationGraph {
    val platformNameProvider: PlatformNameProvider
    val platformContextProvider: PlatformContextProvider
    val counterRepository: CounterRepository
    val homeFeatureService: HomeFeatureService

    @DependencyGraph.Factory
    fun interface Factory {
        fun create(
            @Provides platformNameProvider: PlatformNameProvider,
        ): SharedApplicationGraph
    }

    @Provides
    fun provideCounterRepository(
        repository: FakeCounterRepository,
    ): CounterRepository = repository
}

object SharedDependencies {
    fun createGraph(
        platformNameProvider: PlatformNameProvider,
    ): SharedApplicationGraph {
        return createGraphFactory<SharedApplicationGraph.Factory>()
            .create(platformNameProvider)
    }

    fun createDefaultGraph(): SharedApplicationGraph {
        return createGraph(platformNameProvider = PlatformNameProvider(::platformName))
    }

    fun createHomeFeatureService(
        platformNameProvider: PlatformNameProvider,
    ): HomeFeatureService {
        return createGraph(platformNameProvider).homeFeatureService
    }

    fun createDefaultHomeFeatureService(): HomeFeatureService {
        return createDefaultGraph().homeFeatureService
    }
}
