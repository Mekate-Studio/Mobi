package studio.mekate.b3.home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.slack.circuit.runtime.CircuitContext
import com.slack.circuit.runtime.Navigator
import com.slack.circuit.runtime.presenter.Presenter
import com.slack.circuit.runtime.screen.Screen
import dev.zacsweers.metro.Inject
import studio.mekate.b3.feature.home.HomeFeatureEvent
import studio.mekate.b3.feature.home.HomeFeatureStateFactory

class HomePresenter(
    private val stateFactory: HomeFeatureStateFactory,
) : Presenter<HomeScreenState> {
    private val stateProducer = HomePresenterStateProducer(stateFactory)

    @Composable
    override fun present(): HomeScreenState {
        var refreshCount by rememberSaveable { mutableIntStateOf(0) }
        return remember(refreshCount, stateProducer) {
            stateProducer.create(refreshCount = refreshCount) { updatedRefreshCount ->
                refreshCount = updatedRefreshCount
            }
        }
    }
}

@Inject
class HomePresenterFactory(
    private val stateFactory: HomeFeatureStateFactory,
) : Presenter.Factory {
    override fun create(
        screen: Screen,
        navigator: Navigator,
        context: CircuitContext,
    ): Presenter<*>? {
        return when (screen) {
            HomeScreen -> HomePresenter(stateFactory)
            else -> null
        }
    }
}
