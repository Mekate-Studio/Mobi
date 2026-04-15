package studio.mekate.b3.feature.home

sealed interface CounterLoadFailureReason {
    data object RepositoryUnavailable : CounterLoadFailureReason

    data object Unexpected : CounterLoadFailureReason
}
