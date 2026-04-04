package studio.mekate.b3.feature.home

import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HomeFeatureStateFactoryTest {
    @Test
    fun `should create initial shared state when refresh count is zero`() {
        // given
        val factory = createStateFactory()

        // when
        val state = factory.create(refreshCount = 0)

        // then
        assertEquals("Native shell, shared feature", state.title)
        assertEquals("Shared feature state flowing into the TestOS shell.", state.message)
        assertEquals("Refresh shared state", state.primaryActionLabel)
        assertEquals(0, state.refreshCount)
        assertTrue(state.supportingText.contains("shared-core"))
    }

    @Test
    fun `should increment refresh count when refresh clicked event is reduced`() {
        // given
        val factory = createStateFactory()
        val currentRefreshCount = 2

        // when
        val nextRefreshCount = factory.reduce(
            refreshCount = currentRefreshCount,
            event = HomeFeatureEvent.RefreshClicked,
        )

        // then
        assertEquals(3, nextRefreshCount)
    }

    private fun createStateFactory(
        platformName: String = "TestOS",
    ): HomeFeatureStateFactory {
        return HomeFeatureStateFactory(
            platformContextProvider = PlatformContextProvider(
                PlatformNameProvider { platformName },
            ),
        )
    }
}
