package studio.mekate.mobi.home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.slack.circuit.runtime.CircuitContext
import com.slack.circuit.runtime.Navigator
import com.slack.circuit.runtime.presenter.Presenter
import com.slack.circuit.runtime.screen.Screen
import dev.zacsweers.metro.Inject
import kotlinx.coroutines.launch
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.HomeFeatureService

class HomePresenter(
    private val service: HomeFeatureService,
) : Presenter<HomeScreenState> {
    private val stateProducer = HomePresenterStateProducer(service)

    @Composable
    override fun present(): HomeScreenState {
        var featureState by remember(stateProducer) { mutableStateOf(stateProducer.initialState()) }
        val scope = rememberCoroutineScope()

        return remember(featureState, stateProducer, scope) {
            stateProducer.create(featureState = featureState) { currentCounterValue ->
                if (featureState.counterLoadable !is CounterLoadable.Loading) {
                    scope.launch {
                        featureState = stateProducer.loadingState(counterValue = currentCounterValue)
                        featureState = stateProducer.refreshedState(counterValue = currentCounterValue)
                    }
                }
            }
        }
    }
}

@Inject
class HomePresenterFactory(
    private val service: HomeFeatureService,
) : Presenter.Factory {
    override fun create(
        screen: Screen,
        navigator: Navigator,
        context: CircuitContext,
    ): Presenter<*>? {
        return when (screen) {
            HomeScreen -> HomePresenter(service)
            else -> null
        }
    }
}
