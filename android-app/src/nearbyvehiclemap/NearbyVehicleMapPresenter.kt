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
import kotlinx.coroutines.launch
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.SnapshotBackedNearbyVehicleState
import studio.mekate.mobi.feature.nearbyvehiclemap.isRefreshInFlight
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

        LaunchedEffect(featureState) {
            if (featureState.snapshotState is SnapshotBackedNearbyVehicleState) {
                delay(NearbyVehicleMapFeatureService.REFRESH_INTERVAL_MILLIS.milliseconds)
                featureState =
                    stateProducer.loadingState(
                        currentState = featureState,
                    )
                featureState =
                    stateProducer.refreshedState(
                        currentState = featureState,
                        nowMillis = System.currentTimeMillis(),
                    )
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
                        featureState = stateProducer.loadingState(currentState = featureState)
                        featureState =
                            stateProducer.refreshedState(
                                currentState = featureState,
                                nowMillis = System.currentTimeMillis(),
                            )
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
                    if (!featureState.snapshotState.isRefreshInFlight()) {
                        scope.launch {
                            featureState = stateProducer.loadingState(currentState = featureState)
                            featureState =
                                stateProducer.refreshedState(
                                    currentState = featureState,
                                    nowMillis = nowMillis,
                                )
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
