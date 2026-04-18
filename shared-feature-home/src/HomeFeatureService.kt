package studio.mekate.mobi.feature.home

import dev.zacsweers.metro.Inject
import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.core.CounterRepositoryException
import kotlin.coroutines.cancellation.CancellationException

@Inject
class HomeFeatureService(
    private val counterRepository: CounterRepository,
) {
    fun initialState(): HomeFeatureState = state(counterLoadable = CounterLoadable.Initial)

    fun loadingState(counterValue: Int): HomeFeatureState =
        state(
            counterLoadable =
                CounterLoadable.Loading(
                    previousValue = counterValue.toPreviousValue(),
                ),
        )

    @Suppress("SwallowedException", "TooGenericExceptionCaught")
    suspend fun refresh(counterValue: Int): HomeFeatureState =
        try {
            val nextCounterValue =
                counterRepository.fetchNextCounterValue(
                    currentCounterValue = counterValue,
                )

            state(
                counterLoadable =
                    CounterLoadable.Loaded(
                        value = nextCounterValue,
                    ),
            )
        } catch (error: CancellationException) {
            throw error
        } catch (error: CounterRepositoryException) {
            errorState(
                counterValue = counterValue,
                reason = CounterLoadFailureReason.RepositoryUnavailable,
            )
        } catch (error: Exception) {
            errorState(
                counterValue = counterValue,
                reason = CounterLoadFailureReason.Unexpected,
            )
        }

    fun errorState(
        counterValue: Int,
        reason: CounterLoadFailureReason,
    ): HomeFeatureState =
        state(
            counterLoadable =
                CounterLoadable.Error(
                    previousValue = counterValue.toPreviousValue(),
                    reason = reason,
                ),
        )

    fun unexpectedErrorState(counterValue: Int): HomeFeatureState =
        errorState(
            counterValue = counterValue,
            reason = CounterLoadFailureReason.Unexpected,
        )

    private fun state(counterLoadable: CounterLoadable): HomeFeatureState =
        HomeFeatureState(
            counterLoadable = counterLoadable,
        )

    private fun Int.toPreviousValue(): Int? = takeIf { it > 0 }
}
