package studio.mekate.b3.home

import studio.mekate.b3.feature.home.HomeFeatureEvent
import studio.mekate.b3.feature.home.HomeFeatureStateFactory

class HomePresenterStateProducer(
    private val stateFactory: HomeFeatureStateFactory,
) {
    fun create(
        refreshCount: Int,
        onRefreshCountChanged: (Int) -> Unit,
    ): HomeScreenState {
        val featureState = stateFactory.create(refreshCount = refreshCount)

        return HomeScreenState(
            featureState = featureState,
            eventSink = { event ->
                when (event) {
                    HomeScreenEvent.RefreshClicked -> {
                        onRefreshCountChanged(
                            stateFactory.reduce(
                                refreshCount = refreshCount,
                                event = HomeFeatureEvent.RefreshClicked,
                            ),
                        )
                    }
                }
            },
        )
    }
}
