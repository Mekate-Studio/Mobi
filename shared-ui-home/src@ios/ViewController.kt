package studio.mekate.b3.ui.home

import androidx.compose.ui.window.ComposeUIViewController
import studio.mekate.b3.feature.home.HomeFeatureService

class SharedHomeViewControllerFactory(
    private val service: HomeFeatureService,
) {
    fun create() = ComposeUIViewController { SharedHomeScreen(service = service) }
}
