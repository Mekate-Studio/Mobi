package studio.mekate.mobi.feature.home

sealed interface HomeFeatureEvent {
    data object RefreshClicked : HomeFeatureEvent
}
