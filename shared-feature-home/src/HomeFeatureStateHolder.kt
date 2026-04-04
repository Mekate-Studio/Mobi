package studio.mekate.b3.feature.home

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class HomeFeatureStateHolder(
    private val stateFactory: HomeFeatureStateFactory,
    initialRefreshCount: Int = 0,
) {
    private var refreshCount: Int = initialRefreshCount
    private val mutableState = MutableStateFlow(
        stateFactory.create(refreshCount = initialRefreshCount),
    )

    val state: StateFlow<HomeFeatureState> = mutableState.asStateFlow()

    fun onEvent(event: HomeFeatureEvent) {
        refreshCount = stateFactory.reduce(refreshCount = refreshCount, event = event)
        mutableState.value = stateFactory.create(refreshCount = refreshCount)
    }
}
