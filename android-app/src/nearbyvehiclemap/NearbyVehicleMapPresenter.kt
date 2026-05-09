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
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState

class NearbyVehicleMapPresenter(
    private val service: NearbyVehicleMapFeatureService,
) : Presenter<NearbyVehicleMapScreenState> {
    private val stateProducer = NearbyVehicleMapPresenterStateProducer(service)

    @Composable
    override fun present(): NearbyVehicleMapScreenState {
        var featureState by remember(stateProducer) { mutableStateOf(stateProducer.initialState()) }
        val scope = rememberCoroutineScope()

        LaunchedEffect(featureState) {
            val loadedSnapshot = featureState.snapshotState.loadedSnapshotOrNull()
            if (loadedSnapshot != null) {
                delay(NearbyVehicleMapFeatureService.REFRESH_INTERVAL_MILLIS)
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
                onLocationPermissionGranted = {
                    scope.launch {
                        featureState = stateProducer.permissionGrantedState(currentState = featureState)
                        featureState = stateProducer.loadingState(currentState = featureState)
                        featureState =
                            stateProducer.refreshedState(
                                currentState = featureState,
                                nowMillis = System.currentTimeMillis(),
                            )
                    }
                },
                onLocationPermissionDenied = {
                    featureState = stateProducer.permissionDeniedState(currentState = featureState)
                },
                onLocationTemporarilyUnavailable = {
                    featureState = stateProducer.locationTemporarilyUnavailableState(currentState = featureState)
                },
                onRefreshRequested = { nowMillis ->
                    if (featureState.snapshotState !is NearbyVehicleSnapshotState.Loading &&
                        featureState.snapshotState !is NearbyVehicleSnapshotState.Refreshing
                    ) {
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

    private fun NearbyVehicleSnapshotState.loadedSnapshotOrNull() =
        when (this) {
            is NearbyVehicleSnapshotState.Loaded -> snapshot

            is NearbyVehicleSnapshotState.Failed -> previousSnapshot

            is NearbyVehicleSnapshotState.Refreshing -> snapshot

            NearbyVehicleSnapshotState.Initial,
            NearbyVehicleSnapshotState.Loading,
            -> null
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
