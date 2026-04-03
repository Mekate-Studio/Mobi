package studio.mekate.b3.ui.home

import androidx.compose.ui.window.ComposeUIViewController
import studio.mekate.b3.feature.home.HomeFeatureStateFactory

class SharedHomeViewControllerFactory(
    private val stateFactory: HomeFeatureStateFactory,
) {
    fun create() = ComposeUIViewController { SharedHomeScreen(stateFactory = stateFactory) }
}
