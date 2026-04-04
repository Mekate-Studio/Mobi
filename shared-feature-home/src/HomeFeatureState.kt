package studio.mekate.b3.feature.home

data class HomeFeatureState(
    val title: String,
    val message: String,
    val supportingText: String,
    val primaryActionLabel: String,
    val counterLoadable: CounterLoadable,
)
