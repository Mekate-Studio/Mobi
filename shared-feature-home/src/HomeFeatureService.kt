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
                message = error.toFeatureErrorMessage(),
            )
        }
    }

    fun errorState(
        counterValue: Int,
        message: String,
    ): HomeFeatureState {
        return state(
            counterLoadable = CounterLoadable.Error(
                previousValue = counterValue.toPreviousValue(),
                message = message,
            ),
        )
    }

    fun unexpectedErrorState(
        counterValue: Int,
    ): HomeFeatureState {
        return errorState(
            counterValue = counterValue,
            message = DEFAULT_UNEXPECTED_REFRESH_ERROR_MESSAGE,
        )
    }

    private fun state(
        counterLoadable: CounterLoadable,
    ): HomeFeatureState {
        return HomeFeatureState(
            counterLoadable = counterLoadable,
        )
    }

    private fun Throwable.toFeatureErrorMessage(): String {
        return when (this) {
            is CounterRepositoryException -> message ?: CounterRepositoryException.DEFAULT_MESSAGE
            else -> DEFAULT_UNEXPECTED_REFRESH_ERROR_MESSAGE
        }
    }

    private fun Int.toPreviousValue(): Int? = takeIf { it > 0 }

    internal companion object {
        const val DEFAULT_UNEXPECTED_REFRESH_ERROR_MESSAGE =
            "Something went wrong while loading the next fibonacci counter value."
    }
}
