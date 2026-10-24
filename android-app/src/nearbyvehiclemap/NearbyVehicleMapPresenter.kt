package studio.mekate.mobi.nearbyvehiclemap

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.slack.circuit.retained.rememberRetained
import com.slack.circuit.runtime.CircuitContext
import com.slack.circuit.runtime.Navigator
import com.slack.circuit.runtime.presenter.Presenter
import com.slack.circuit.runtime.screen.Screen
import dev.zacsweers.metro.Inject
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureService
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.VisibleRiderLocationState
import studio.mekate.mobi.feature.nearbyvehiclemap.canRequestRefresh
import studio.mekate.mobi.feature.nearbyvehiclemap.cancelledRefreshState
import kotlin.coroutines.cancellation.CancellationException
import kotlin.time.Duration.Companion.milliseconds

class NearbyVehicleMapPresenter(
    private val service: NearbyVehicleMapFeatureService,
) : Presenter<NearbyVehicleMapScreenState> {
    private val stateProducer = NearbyVehicleMapPresenterStateProducer(service)

    @Composable
    @Suppress("LongMethod") // State transitions stay together at the Circuit presentation boundary.
    override fun present(): NearbyVehicleMapScreenState {
        var readyState by rememberRetained(service) { mutableStateOf(stateProducer.initialState()) }
        var featureState by remember(service) {
            val restored =
                if (readyState.riderLocationState is VisibleRiderLocationState) {
                    stateProducer
                        .stateAfterTimePasses(readyState, System.currentTimeMillis())
                        .copy(riderLocationState = RiderLocationState.Resolving)
                } else {
                    readyState
                }
            mutableStateOf(restored)
        }
        // Only refresh requests belong to this scope; location updates supersede its children.
        val refreshScope = rememberCoroutineScope()

        fun applyState(state: NearbyVehicleMapFeatureState) {
            if (!refreshScope.isActive) return
            readyState = state.cancelledRefreshState()
            featureState = state
        }

        suspend fun refresh(nowMillis: Long) {
            applyState(stateProducer.loadingState(currentState = featureState))
            val refreshedState =
                try {
                    stateProducer.refreshedState(
                        currentState = featureState,
                        nowMillis = nowMillis,
                    )
                } catch (error: CancellationException) {
                    currentCoroutineContext().ensureActive()
                    applyState(featureState.cancelledRefreshState())
                    throw error
                }
            currentCoroutineContext().ensureActive()
            if (featureState.riderLocationState is VisibleRiderLocationState) {
                applyState(refreshedState.copy(riderLocationState = featureState.riderLocationState))
            }
        }

        LaunchedEffect(stateProducer) {
            while (isActive) {
                delay(NearbyVehicleMapFeatureService.REFRESH_INTERVAL_MILLIS.milliseconds)
                refreshScope
                    .launch {
                        val nowMillis = System.currentTimeMillis()
                        if (featureState.canRequestRefresh() && stateProducer.shouldRefresh(featureState, nowMillis)) {
                            refresh(nowMillis)
                        }
                    }.join()
            }
        }

        return remember(featureState, stateProducer, refreshScope) {
            stateProducer.create(
                featureState = featureState,
                onPreciseLocationResolved = { location ->
                    refreshScope.coroutineContext.cancelChildren()
                    refreshScope.launch {
                        applyState(
                            stateProducer.preciseLocationResolvedState(
                                currentState = featureState,
                                location = location,
                            ),
                        )
                        refresh(System.currentTimeMillis())
                    }
                },
                onLocationAccessBlocked = { reason ->
                    refreshScope.coroutineContext.cancelChildren()
                    applyState(
                        stateProducer.locationAccessBlockedState(
                            currentState = featureState,
                            reason = reason,
                        ),
                    )
                },
                onLocationTemporarilyUnavailable = {
                    val currentState =
                        if (featureState.riderLocationState == RiderLocationState.Resolving) {
                            featureState.copy(riderLocationState = readyState.riderLocationState)
                        } else {
                            featureState
                        }
                    applyState(stateProducer.locationTemporarilyUnavailableState(currentState))
                },
                onRefreshRequested = { nowMillis ->
                    refreshScope.launch {
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
