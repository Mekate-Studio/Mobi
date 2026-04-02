package studio.mekate.b3.feature.home

import studio.mekate.b3.core.buildGreeting
import studio.mekate.b3.core.platformName

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

class HomeFeatureStateFactory {
    fun create(refreshCount: Int): HomeFeatureState {
        val platform = platformName()
        val title = "Native shell, shared feature"
        val message = buildGreeting("$platform from shared KMP")
        val supportingText = when (refreshCount) {
            0 -> "This feature state lives in shared code and can be rendered by native or shared UI."
            1 -> "The shared reducer has already handled one refresh for $platform."
            else -> "The shared reducer has handled $refreshCount refreshes for $platform."
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
//ok now we can proceed to the original goal of adding TCA to the iOS app and replicate a similar architecture we have in Circuit considering the shared feature parts of feature-home