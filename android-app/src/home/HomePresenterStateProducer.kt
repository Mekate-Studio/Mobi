package studio.mekate.mobi.home

import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.HomeFeatureState
import studio.mekate.mobi.feature.home.currentValueForRefresh

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
                        onRefreshRequested(
                            featureState.counterLoadable.currentValueForRefresh(),
                        )
                    }
                }
            },
        )
    }
}
