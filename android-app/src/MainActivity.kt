package studio.mekate.b3

import android.os.Bundle
import android.os.Parcel
import android.os.Parcelable
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.slack.circuit.foundation.Circuit
import com.slack.circuit.foundation.CircuitCompositionLocals
import com.slack.circuit.foundation.CircuitContent
import com.slack.circuit.runtime.CircuitContext
import com.slack.circuit.runtime.CircuitUiState
import com.slack.circuit.runtime.Navigator
import com.slack.circuit.runtime.presenter.Presenter
import com.slack.circuit.runtime.screen.Screen
import com.slack.circuit.runtime.ui.Ui
import com.slack.circuit.runtime.ui.ui
import studio.mekate.b3.di.SharedDependencies
import studio.mekate.b3.feature.home.HomeFeatureEvent
import studio.mekate.b3.feature.home.HomeFeatureState
import studio.mekate.b3.feature.home.HomeFeatureStateFactory
import studio.mekate.b3.ui.home.HomeContent
import studio.mekate.b3.ui.home.SharedHomeScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppShell()
        }
    }
}

@Composable
private fun AppShell() {
    var destination by rememberSaveable { mutableIntStateOf(AppDestination.NativeHome.ordinal) }
    val selectedDestination = AppDestination.entries[destination]
    val homeFeatureStateFactory = remember {
        SharedDependencies.createDefaultHomeFeatureStateFactory()
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                AppDestination.entries.forEach { item ->
                    NavigationBarItem(
                        selected = selectedDestination == item,
                        onClick = { destination = item.ordinal },
                        icon = { Text(item.shortLabel) },
                        label = { Text(item.label) },
                    )
                }
            }
        },
    ) { paddingValues ->
        when (selectedDestination) {
            AppDestination.NativeHome -> HomeCircuitHost(
                stateFactory = homeFeatureStateFactory,
                modifier = Modifier.padding(paddingValues),
            )
            AppDestination.SharedComposeDemo -> SharedHomeScreen(
                stateFactory = homeFeatureStateFactory,
                modifier = Modifier.padding(paddingValues),
            )
        }
    }
}

private enum class AppDestination(
    val label: String,
    val shortLabel: String,
) {
    NativeHome(label = "Native Home", shortLabel = "N"),
    SharedComposeDemo(label = "Shared UI", shortLabel = "S"),
}

@Composable
private fun HomeCircuitHost(
    stateFactory: HomeFeatureStateFactory,
    modifier: Modifier = Modifier,
) {
    val circuit = remember {
        Circuit.Builder()
            .addPresenterFactory(HomePresenterFactory(stateFactory))
            .addUiFactory(HomeUiFactory())
            .build()
    }

    CircuitCompositionLocals(circuit) {
        CircuitContent(HomeScreen, modifier = modifier)
    }
}

data object HomeScreen : Screen {
    override fun describeContents(): Int = 0

    override fun writeToParcel(parcel: Parcel, flags: Int) = Unit

    @JvmField
    val CREATOR: Parcelable.Creator<HomeScreen> = object : Parcelable.Creator<HomeScreen> {
        override fun createFromParcel(parcel: Parcel): HomeScreen = HomeScreen

        override fun newArray(size: Int): Array<HomeScreen?> = arrayOfNulls(size)
    }
}

data class HomeScreenState(
    val featureState: HomeFeatureState,
    val eventSink: (HomeScreenEvent) -> Unit,
) : CircuitUiState

sealed interface HomeScreenEvent {
    data object RefreshClicked : HomeScreenEvent
}

class HomePresenter(
    private val stateFactory: HomeFeatureStateFactory,
) : Presenter<HomeScreenState> {
    @Composable
    override fun present(): HomeScreenState {
        var refreshCount by rememberSaveable { mutableIntStateOf(0) }
        val featureState = remember(refreshCount) {
            stateFactory.create(refreshCount = refreshCount)
        }

        return HomeScreenState(
            featureState = featureState,
            eventSink = { event ->
                when (event) {
                    HomeScreenEvent.RefreshClicked -> {
                        refreshCount = stateFactory.reduce(
                            refreshCount = refreshCount,
                            event = HomeFeatureEvent.RefreshClicked,
                        )
                    }
                }
            },
        )
    }
}

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
