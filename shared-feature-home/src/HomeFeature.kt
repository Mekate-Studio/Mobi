package studio.mekate.b3.feature.home

import dev.zacsweers.metro.Inject
import studio.mekate.b3.core.PlatformContextProvider

data class HomeFeatureState(
    val title: String,
    val message: String,
    val supportingText: String,
    val refreshCount: Int,
    val primaryActionLabel: String,
)

sealed interface HomeFeatureEvent {
    data object RefreshClicked : HomeFeatureEvent
}

@Inject
class HomeFeatureStateFactory(
    private val platformContextProvider: PlatformContextProvider,
) {
    fun create(refreshCount: Int): HomeFeatureState {
        val platform = platformContextProvider.current().name
        val title = "Native shell, shared feature"
        val message = "Shared feature state flowing into the $platform shell."
        val supportingText = when (refreshCount) {
            0 -> "shared-core exposes platform context, shared-feature-home turns it into feature state, and platform shells decide how to render it."
            1 -> "The shared reducer has already handled one refresh for the $platform shell."
            else -> "The shared reducer has handled $refreshCount refreshes for the $platform shell."
        }

        return HomeFeatureState(
            title = title,
            message = message,
            supportingText = supportingText,
            refreshCount = refreshCount,
            primaryActionLabel = "Refresh shared state",
        )
    }

    fun reduce(refreshCount: Int, event: HomeFeatureEvent): Int {
        return when (event) {
            HomeFeatureEvent.RefreshClicked -> refreshCount + 1
        }
    }
}
