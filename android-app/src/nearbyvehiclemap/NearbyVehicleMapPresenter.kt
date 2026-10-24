package studio.mekate.mobi.nearbyvehiclemap

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.VisibleRiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import kotlin.time.Duration.Companion.milliseconds

class NearbyVehicleMapPresenter(
    private val service: NearbyVehicleMapFeatureService,
) : Presenter<NearbyVehicleMapScreenState> {
    private val stateProducer = NearbyVehicleMapPresenterStateProducer(service)

    @Composable
    @Suppress("LongMethod") // State transitions stay together at the Circuit presentation boundary.
    override fun present(): NearbyVehicleMapScreenState {
        var featureState by remember(stateProducer) { mutableStateOf(stateProducer.initialState()) }
        val scope = rememberCoroutineScope()

        suspend fun refresh(nowMillis: Long) {
            featureState = stateProducer.loadingState(currentState = featureState)
            val refreshedState =
                stateProducer.refreshedState(
                    currentState = featureState,
                    nowMillis = nowMillis,
                )
            if (featureState.riderLocationState is VisibleRiderLocationState) {
                featureState = refreshedState.copy(riderLocationState = featureState.riderLocationState)
            }
        }

        LaunchedEffect(stateProducer) {
            while (isActive) {
                delay(NearbyVehicleMapFeatureService.REFRESH_INTERVAL_MILLIS.milliseconds)
                val nowMillis = System.currentTimeMillis()
                if (!featureState.canRequestRefresh() || !stateProducer.shouldRefresh(featureState, nowMillis)) {
                    continue
                }
                refresh(nowMillis)
            }
        }

        return remember(featureState, stateProducer, scope) {
            stateProducer.create(
                featureState = featureState,
                onPreciseLocationResolved = { location ->
                    scope.launch {
                        featureState =
                            stateProducer.preciseLocationResolvedState(
                                currentState = featureState,
                                location = location,
                            )
                        refresh(System.currentTimeMillis())
                    }
                },
                onLocationAccessBlocked = { reason ->
                    featureState =
                        stateProducer.locationAccessBlockedState(
                            currentState = featureState,
                            reason = reason,
                        )
                },
                onLocationTemporarilyUnavailable = {
                    featureState = stateProducer.locationTemporarilyUnavailableState(currentState = featureState)
                },
                onRefreshRequested = { nowMillis ->
                    scope.launch {
                        if (featureState.canRequestRefresh()) {
                            refresh(nowMillis)
                        }
                    }
                },
            )
        }
    }
}

@Inject
class NearbyVehicleMapPresenterFactory(
    private val service: NearbyVehicleMapFeatureService,
) : Presenter.Factory {
    override fun create(
        screen: Screen,
        navigator: Navigator,
        context: CircuitContext,
    ): Presenter<*>? =
        when (screen) {
            NearbyVehicleMapScreen -> NearbyVehicleMapPresenter(service)
            else -> null
        }
}
