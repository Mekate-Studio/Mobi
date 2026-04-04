package studio.mekate.b3.feature.home

import dev.zacsweers.metro.Inject
import studio.mekate.b3.core.CounterRepositoryException
import studio.mekate.b3.core.CounterRepository

@Inject
class HomeFeatureService(
    private val stateFactory: HomeFeatureStateFactory,
    private val counterRepository: CounterRepository,
) {
    fun initialState(): HomeFeatureState {
        return stateFactory.create(
            counterLoadable = CounterLoadable.Initial,
        )
    }

    fun loadingState(
        counterValue: Int,
    ): HomeFeatureState {
        return stateFactory.create(
            counterLoadable = CounterLoadable.Loading(
                previousValue = counterValue.takeIf { it > 0 },
            ),
        )
    }

    suspend fun refresh(
        counterValue: Int,
    ): HomeFeatureState {
        return try {
            val nextCounterValue = counterRepository.fetchNextCounterValue(
                currentCounterValue = counterValue,
            )

            stateFactory.create(
                counterLoadable = CounterLoadable.Loaded(
                    value = nextCounterValue,
                ),
            )
        } catch (error: CounterRepositoryException) {
            errorState(
                counterValue = counterValue,
                message = error.message ?: CounterRepositoryException.DEFAULT_MESSAGE,
            )
        }
    }

    fun errorState(
        counterValue: Int,
        message: String,
    ): HomeFeatureState {
        return stateFactory.create(
            counterLoadable = CounterLoadable.Error(
                previousValue = counterValue.takeIf { it > 0 },
                message = message,
            ),
        )
    }
}
