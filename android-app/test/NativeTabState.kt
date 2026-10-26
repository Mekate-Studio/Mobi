package studio.mekate.mobi

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.State
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import app.cash.molecule.RecompositionMode
import app.cash.molecule.moleculeFlow
import com.slack.circuit.foundation.Circuit
import com.slack.circuit.runtime.ui.ui
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import studio.mekate.mobi.di.SharedApplicationGraph
import studio.mekate.mobi.home.HomeScreen
import studio.mekate.mobi.home.HomeScreenState
import studio.mekate.mobi.nearbyvehiclemap.NearbyVehicleMapScreen
import studio.mekate.mobi.nearbyvehiclemap.NearbyVehicleMapScreenState

internal sealed interface NativeTabState {
    data class Home(
        val state: HomeScreenState,
    ) : NativeTabState

    data class Nearby(
        val state: NearbyVehicleMapScreenState,
    ) : NativeTabState
}

@OptIn(ExperimentalCoroutinesApi::class)
internal fun TestScope.nativeTabContent(
    destination: State<AppDestination>,
    sharedGraph: SharedApplicationGraph,
    owner: TabContentOwner? = null,
    nearbyEffects: @Composable (NearbyVehicleMapScreenState) -> Unit = {},
): Flow<NativeTabState> =
    channelFlow {
        val graph = recordingAppGraph(sharedGraph, nearbyEffects) { trySend(it) }
        val contentOwner = owner ?: TabContentOwner()
        try {
            moleculeFlow(RecompositionMode.Immediate) {
                CompositionLocalProvider(
                    LocalLifecycleOwner provides contentOwner,
                    LocalViewModelStoreOwner provides contentOwner,
                ) {
                    AppDestinationContent(destination.value, graph, sharedGraph.homeFeatureService)
                }
            }.collect()
        } finally {
            contentOwner.lifecycle.currentState = Lifecycle.State.DESTROYED
            contentOwner.viewModelStore.clear()
        }
    }.flowOn(StandardTestDispatcher(testScheduler))

private fun recordingAppGraph(
    sharedGraph: SharedApplicationGraph,
    nearbyEffects: @Composable (NearbyVehicleMapScreenState) -> Unit,
    onState: (NativeTabState) -> Unit,
): AndroidAppGraph {
    val productionGraph = AndroidDependencies.createGraph(sharedGraph)
    return object : AndroidAppGraph {
        // Keep Metro's real unscoped factories; substitute only rendering observers.
        override val circuit: Circuit
            get() =
                productionGraph.circuit
                    .newBuilder()
                    .apply {
                        uiFactories.clear()
                        addUiFactory { screen, _ ->
                            when (screen) {
                                HomeScreen -> {
                                    ui<HomeScreenState> {
                                        state,
                                        _,
                                        ->
                                        SideEffect { onState(NativeTabState.Home(state)) }
                                    }
                                }

                                NearbyVehicleMapScreen -> {
                                    ui<NearbyVehicleMapScreenState> {
                                        state,
                                        _,
                                        ->
                                        nearbyEffects(state)
                                        SideEffect { onState(NativeTabState.Nearby(state)) }
                                    }
                                }

                                else -> {
                                    null
                                }
                            }
                        }
                    }.build()
    }
}

internal class TabContentOwner(
    initialState: Lifecycle.State = Lifecycle.State.RESUMED,
) : LifecycleOwner,
    ViewModelStoreOwner {
    override val viewModelStore = ViewModelStore()
    override val lifecycle =
        LifecycleRegistry.createUnsafe(this).apply {
            currentState = initialState
        }
}
