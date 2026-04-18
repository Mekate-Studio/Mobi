package studio.mekate.mobi.home

import com.slack.circuit.runtime.CircuitContext
import com.slack.circuit.runtime.screen.Screen
import com.slack.circuit.runtime.ui.Ui
import com.slack.circuit.runtime.ui.ui
import dev.zacsweers.metro.Inject
import studio.mekate.mobi.feature.home.HomeFeatureEvent
import studio.mekate.mobi.ui.home.HomeContent

@Inject
class HomeUiFactory : Ui.Factory {
    override fun create(
        screen: Screen,
        context: CircuitContext,
    ): Ui<*>? {
        return when (screen) {
            HomeScreen -> ui<HomeScreenState> { state, modifier ->
                HomeContent(
                    state = state.featureState,
                    modifier = modifier,
                    onEvent = { event ->
                        when (event) {
                            HomeFeatureEvent.RefreshClicked -> {
                                state.eventSink(HomeScreenEvent.RefreshClicked)
                            }
                        }
                    },
                )
            }

            else -> null
        }
    }
}
