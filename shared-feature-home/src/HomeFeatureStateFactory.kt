package studio.mekate.b3.feature.home

import dev.zacsweers.metro.Inject
import studio.mekate.b3.core.PlatformContextProvider

@Inject
class HomeFeatureStateFactory(
    private val platformContextProvider: PlatformContextProvider,
) {
    fun create(
        counterValue: Int,
        isLoading: Boolean,
    ): HomeFeatureState {
        val platform = platformContextProvider.current().name
        val title = "Native shell, shared feature"
        val message = "Shared feature state flowing into the $platform shell."
        val supportingText = when {
            isLoading -> "Loading the next fibonacci counter value from the fake repository for the $platform shell."
            counterValue == 0 -> "shared-core exposes platform context, shared-feature-home fetches counter values from a fake repository, and platform shells decide how to render them."
            else -> "The fake repository returned fibonacci counter value $counterValue for the $platform shell."
        }

        return HomeFeatureState(
            title = title,
            message = message,
            supportingText = supportingText,
            counterValue = counterValue,
            primaryActionLabel = "Load next counter value",
            isLoading = isLoading,
        )
    }
}
