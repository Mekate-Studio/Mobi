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
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.currentValueForRefresh
import kotlin.coroutines.cancellation.CancellationException

class HomePresenter(
    private val service: HomeFeatureService,
) : Presenter<HomeScreenState> {
    private val stateProducer = HomePresenterStateProducer(service)

    @Composable
    override fun present(): HomeScreenState {
        var featureState by remember(stateProducer) { mutableStateOf(stateProducer.initialState()) }
        val scope = rememberCoroutineScope()

        return remember(featureState, stateProducer, scope) {
            stateProducer.create(featureState = featureState) {
                scope.launch {
                    if (featureState.counterLoadable !is CounterLoadable.Loading) {
                        val previousState = featureState
                        val currentCounterValue = previousState.counterLoadable.currentValueForRefresh()
                        featureState = stateProducer.loadingState(counterValue = currentCounterValue)
                        try {
                            featureState = stateProducer.refreshedState(counterValue = currentCounterValue)
                        } catch (error: CancellationException) {
                            if (scope.isActive) featureState = previousState
                            throw error
                        }
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
    ): Presenter<*>? =
        when (screen) {
            HomeScreen -> HomePresenter(service)
            else -> null
        }
}
