package studio.mekate.mobi

import com.slack.circuit.foundation.Circuit
import dev.zacsweers.metro.DependencyGraph
import dev.zacsweers.metro.Provides
import dev.zacsweers.metro.createGraphFactory
import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.di.SharedApplicationGraph
import studio.mekate.mobi.home.HomePresenterFactory
import studio.mekate.mobi.home.HomeUiFactory

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
