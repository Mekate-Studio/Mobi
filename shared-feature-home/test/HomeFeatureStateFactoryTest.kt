package studio.mekate.b3.feature.home

import studio.mekate.b3.core.PlatformContextProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HomeFeatureStateFactoryTest {
    private val factory = HomeFeatureStateFactory(
        platformContextProvider = PlatformContextProvider { "TestOS" },
    )

    @Test
    fun buildsInitialState() {
        val state = factory.create(refreshCount = 0)

        assertEquals("Native shell, shared feature", state.title)
        assertEquals("Shared feature state flowing into the TestOS shell.", state.message)
        assertEquals("Refresh shared state", state.primaryActionLabel)
        assertEquals(0, state.refreshCount)
        assertTrue(state.supportingText.contains("shared-core"))
    }

    @Test
    fun incrementsRefreshCount() {
        assertEquals(3, factory.reduce(refreshCount = 2, event = HomeFeatureEvent.RefreshClicked))
    }
}
