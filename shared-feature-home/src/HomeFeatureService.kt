package studio.mekate.b3.feature.home

import dev.zacsweers.metro.Inject
import studio.mekate.b3.core.CounterRepository

@Inject
class HomeFeatureService(
    private val stateFactory: HomeFeatureStateFactory,
    private val counterRepository: CounterRepository,
) {
    fun initialState(
        counterValue: Int = 0,
    ): HomeFeatureState {
        return stateFactory.create(
            counterValue = counterValue,
            isLoading = false,
        )
    }

    fun loadingState(
        counterValue: Int,
    ): HomeFeatureState {
        return stateFactory.create(
            counterValue = counterValue,
            isLoading = true,
        )
    }

    suspend fun refresh(
        counterValue: Int,
    ): HomeFeatureState {
        val nextCounterValue = counterRepository.fetchNextCounterValue(
            currentCounterValue = counterValue,
        )

        return stateFactory.create(
            counterValue = nextCounterValue,
            isLoading = false,
        )
    }
}
