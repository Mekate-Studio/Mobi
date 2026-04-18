package studio.mekate.mobi.feature.home

sealed interface CounterLoadFailureReason {
    data object RepositoryUnavailable : CounterLoadFailureReason

    data object Unexpected : CounterLoadFailureReason
}
