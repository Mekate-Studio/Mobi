package studio.mekate.b3

import com.slack.circuit.foundation.Circuit
import dev.zacsweers.metro.DependencyGraph
import dev.zacsweers.metro.Provides
import dev.zacsweers.metro.createGraphFactory
import studio.mekate.b3.core.CounterRepository
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.di.SharedApplicationGraph
import studio.mekate.b3.home.HomePresenterFactory
import studio.mekate.b3.home.HomeUiFactory

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
    fun providePlatformNameProvider(
        sharedApplicationGraph: SharedApplicationGraph,
    ): PlatformNameProvider {
        return sharedApplicationGraph.platformNameProvider
    }

    @Provides
    fun provideCounterRepository(
        sharedApplicationGraph: SharedApplicationGraph,
    ): CounterRepository {
        return sharedApplicationGraph.counterRepository
    }

    @Provides
    fun provideCircuit(
        homePresenterFactory: HomePresenterFactory,
        homeUiFactory: HomeUiFactory,
    ): Circuit {
        return Circuit.Builder()
            .addPresenterFactory(homePresenterFactory)
            .addUiFactory(homeUiFactory)
            .build()
    }
}

object AndroidDependencies {
    fun createGraph(
        sharedApplicationGraph: SharedApplicationGraph,
    ): AndroidAppGraph {
        return createGraphFactory<AndroidAppGraph.Factory>()
            .create(sharedApplicationGraph)
    }
}
