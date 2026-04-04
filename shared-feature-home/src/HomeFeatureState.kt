package studio.mekate.b3.feature.home

data class HomeFeatureState(
    val title: String,
    val message: String,
    val supportingText: String,
    val counterValue: Int,
    val primaryActionLabel: String,
    val isLoading: Boolean,
)
