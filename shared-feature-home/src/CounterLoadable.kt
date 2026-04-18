package studio.mekate.mobi.feature.home

sealed interface CounterLoadable {
    data object Initial : CounterLoadable

    data class Loading(
        val previousValue: Int?,
    ) : CounterLoadable

    data class Loaded(
        val value: Int,
    ) : CounterLoadable

    data class Error(
        val previousValue: Int?,
        val reason: CounterLoadFailureReason,
    ) : CounterLoadable
}

fun CounterLoadable.currentValueOrNull(): Int? =
    when (this) {
        CounterLoadable.Initial -> null
        is CounterLoadable.Loading -> previousValue
        is CounterLoadable.Loaded -> value
        is CounterLoadable.Error -> previousValue
    }

fun CounterLoadable.currentValueForRefresh(): Int = currentValueOrNull() ?: 0
