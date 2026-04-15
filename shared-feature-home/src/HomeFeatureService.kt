package studio.mekate.b3.feature.home

import dev.zacsweers.metro.Inject
import studio.mekate.b3.core.CounterRepository
import studio.mekate.b3.core.CounterRepositoryException
import kotlin.coroutines.cancellation.CancellationException

@Inject
class HomeFeatureService(
    private val counterRepository: CounterRepository,
) {
    fun initialState(): HomeFeatureState {
        return state(counterLoadable = CounterLoadable.Initial)
    }

    fun loadingState(
        counterValue: Int,
    ): HomeFeatureState {
        return state(
            counterLoadable = CounterLoadable.Loading(
                previousValue = counterValue.toPreviousValue(),
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

            state(
                counterLoadable = CounterLoadable.Loaded(
                    value = nextCounterValue,
                ),
            )
        } catch (error: Throwable) {
            if (error is CancellationException) throw error

            errorState(
                counterValue = counterValue,
                reason = error.toFailureReason(),
            )
        }
    }

    fun errorState(
        counterValue: Int,
        reason: CounterLoadFailureReason,
    ): HomeFeatureState {
        return state(
            counterLoadable = CounterLoadable.Error(
                previousValue = counterValue.toPreviousValue(),
                reason = reason,
            ),
        )
    }

    fun unexpectedErrorState(
        counterValue: Int,
    ): HomeFeatureState {
        return errorState(
            counterValue = counterValue,
            reason = CounterLoadFailureReason.Unexpected,
        )
    }

    private fun state(
        counterLoadable: CounterLoadable,
    ): HomeFeatureState {
        return HomeFeatureState(
            counterLoadable = counterLoadable,
        )
    }

    private fun Throwable.toFailureReason(): CounterLoadFailureReason {
        return when (this) {
            is CounterRepositoryException -> CounterLoadFailureReason.RepositoryUnavailable
            else -> CounterLoadFailureReason.Unexpected
        }
    }

    private fun Int.toPreviousValue(): Int? = takeIf { it > 0 }
}
