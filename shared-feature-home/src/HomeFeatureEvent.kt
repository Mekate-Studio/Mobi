package studio.mekate.b3.feature.home

sealed interface HomeFeatureEvent {
    data object RefreshClicked : HomeFeatureEvent
}
