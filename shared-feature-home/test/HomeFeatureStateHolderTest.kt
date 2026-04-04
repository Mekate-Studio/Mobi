package studio.mekate.b3.feature.home

import app.cash.turbine.test
import kotlinx.coroutines.test.runTest
import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import kotlin.test.Test
import kotlin.test.assertEquals

class HomeFeatureStateHolderTest {
    @Test
    fun `should emit refreshed shared state when refresh event is received`() = runTest {
        // given
        val holder = createStateHolder()

        // when / then
        holder.state.test {
            val initialState = awaitItem()
            assertEquals(0, initialState.refreshCount)
            assertEquals("Shared feature state flowing into the TestOS shell.", initialState.message)
            assertEquals(
                "shared-core exposes platform context, shared-feature-home turns it into feature state, and platform shells decide how to render it.",
                initialState.supportingText,
            )

            holder.onEvent(HomeFeatureEvent.RefreshClicked)

            val refreshedState = awaitItem()
            assertEquals(1, refreshedState.refreshCount)
            assertEquals(
                "The shared reducer has already handled one refresh for the TestOS shell.",
                refreshedState.supportingText,
            )
            cancelAndIgnoreRemainingEvents()
        }
    }

    private fun createStateHolder(
        platformName: String = "TestOS",
        initialRefreshCount: Int = 0,
    ): HomeFeatureStateHolder {
        return HomeFeatureStateHolder(
            stateFactory = HomeFeatureStateFactory(
                platformContextProvider = PlatformContextProvider(
                    platformNameProvider = PlatformNameProvider { platformName },
                ),
            ),
            initialRefreshCount = initialRefreshCount,
        )
    }
}
