package studio.mekate.mobi.home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.LifecycleStartEffect
import com.slack.circuit.retained.rememberRetained
import com.slack.circuit.runtime.CircuitContext
import com.slack.circuit.runtime.Navigator
import com.slack.circuit.runtime.presenter.Presenter
import com.slack.circuit.runtime.screen.Screen
import dev.zacsweers.metro.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.job
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
        var readyState by rememberRetained(service) { mutableStateOf(stateProducer.initialState()) }
        var featureState by remember(service) { mutableStateOf(readyState) }
        val compositionScope = rememberCoroutineScope()
        val requestScope = remember(service) { mutableStateOf<CoroutineScope?>(null) }

        LifecycleStartEffect(service, compositionScope) {
            val scope =
                CoroutineScope(
                    compositionScope.coroutineContext + SupervisorJob(compositionScope.coroutineContext.job),
                )
            requestScope.value = scope
            onStopOrDispose {
                scope.cancel()
                requestScope.value = null
                featureState = readyState
            }
        }

        return remember(featureState, stateProducer, requestScope) {
            stateProducer.create(featureState = featureState) {
                val scope = requestScope.value ?: return@create
                scope.launch {
                    if (featureState.counterLoadable !is CounterLoadable.Loading) {
                        val previousState = featureState
                        val currentCounterValue = previousState.counterLoadable.currentValueForRefresh()
                        featureState = stateProducer.loadingState(counterValue = currentCounterValue)
                        try {
                            val refreshedState = stateProducer.refreshedState(counterValue = currentCounterValue)
                            currentCoroutineContext().ensureActive()
                            readyState = refreshedState
                            featureState = refreshedState
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
