package studio.mekate.b3.di

import dev.zacsweers.metro.DependencyGraph
import dev.zacsweers.metro.Provides
import dev.zacsweers.metro.createGraphFactory
import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.core.platformName
import studio.mekate.b3.feature.home.HomeFeatureStateFactory

@DependencyGraph
interface SharedApplicationGraph {
    val platformNameProvider: PlatformNameProvider
    val platformContextProvider: PlatformContextProvider
    val homeFeatureStateFactory: HomeFeatureStateFactory

    @DependencyGraph.Factory
    fun interface Factory {
        fun create(
            @Provides platformNameProvider: PlatformNameProvider,
        ): SharedApplicationGraph
    }
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

    fun createHomeFeatureStateFactory(
        platformNameProvider: PlatformNameProvider,
    ): HomeFeatureStateFactory {
        return createGraph(platformNameProvider).homeFeatureStateFactory
    }

    fun createDefaultHomeFeatureStateFactory(): HomeFeatureStateFactory {
        return createDefaultGraph().homeFeatureStateFactory
    }
}
