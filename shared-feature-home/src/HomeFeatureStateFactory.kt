package studio.mekate.b3.feature.home

import dev.zacsweers.metro.Inject
import studio.mekate.b3.core.PlatformContextProvider

@Inject
class HomeFeatureStateFactory(
    private val platformContextProvider: PlatformContextProvider,
) {
    fun create(
        counterLoadable: CounterLoadable,
    ): HomeFeatureState {
        val platform = platformContextProvider.current().name
        val title = "Native shell, shared feature"
        val message = "Shared feature state flowing into the $platform shell."
        val supportingText = when (counterLoadable) {
            CounterLoadable.Initial -> {
                "shared-core exposes platform context, shared-feature-home fetches counter values from a fake repository, and platform shells decide how to render them."
            }

            is CounterLoadable.Loading -> {
                "Loading the next fibonacci counter value from the fake repository for the $platform shell."
            }

            is CounterLoadable.Loaded -> {
                "The fake repository returned fibonacci counter value ${counterLoadable.value} for the $platform shell."
            }

            is CounterLoadable.Error -> {
                buildString {
                    append(counterLoadable.message)
                    if (counterLoadable.previousValue != null) {
                        append(" Showing last known counter value ${counterLoadable.previousValue} in the $platform shell.")
                    } else {
                        append(" No fibonacci counter value was loaded yet for the $platform shell.")
                    }
                }
            }
        }

        return HomeFeatureState(
            title = title,
            message = message,
            supportingText = supportingText,
            primaryActionLabel = "Load next counter value",
            counterLoadable = counterLoadable,
        )
    }
}
