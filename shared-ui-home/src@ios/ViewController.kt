package studio.mekate.mobi.ui.home

import androidx.compose.ui.window.ComposeUIViewController
import studio.mekate.mobi.feature.home.HomeFeatureService

class SharedHomeViewControllerFactory(
    private val service: HomeFeatureService,
) {
    fun create() = ComposeUIViewController { SharedHomeScreen(service = service) }
}
