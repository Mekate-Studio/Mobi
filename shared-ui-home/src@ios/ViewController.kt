package studio.mekate.b3.ui.home

import androidx.compose.ui.window.ComposeUIViewController

class SharedHomeViewControllerFactory {
    fun create() = ComposeUIViewController { SharedHomeScreen() }
}
