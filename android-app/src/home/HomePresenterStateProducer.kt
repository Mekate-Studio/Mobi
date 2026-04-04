package studio.mekate.b3.home

import studio.mekate.b3.feature.home.HomeFeatureService
import studio.mekate.b3.feature.home.HomeFeatureState

class HomePresenterStateProducer(
    private val service: HomeFeatureService,
) {
    fun initialState(): HomeFeatureState = service.initialState()

    fun loadingState(
        counterValue: Int,
    ): HomeFeatureState = service.loadingState(counterValue = counterValue)

    suspend fun refreshedState(
        counterValue: Int,
    ): HomeFeatureState = service.refresh(counterValue = counterValue)

    fun create(
        featureState: HomeFeatureState,
        onRefreshRequested: (Int) -> Unit,
    ): HomeScreenState {
        return HomeScreenState(
            featureState = featureState,
            eventSink = { event ->
                when (event) {
                    HomeScreenEvent.RefreshClicked -> {
                        onRefreshRequested(featureState.counterValue)
                    }
                }
            },
        )
    }
}
