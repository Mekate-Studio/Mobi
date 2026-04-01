package studio.mekate.b3.feature.home

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HomeFeatureStateFactoryTest {
    private val factory = HomeFeatureStateFactory()

    @Test
    fun buildsInitialState() {
        val state = factory.create(refreshCount = 0)

        assertEquals("Native shell, shared feature", state.title)
        assertEquals("Refresh shared state", state.primaryActionLabel)
        assertEquals(0, state.refreshCount)
        assertTrue(state.supportingText.contains("shared code"))
    }

    @Test
    fun incrementsRefreshCount() {
        assertEquals(3, factory.reduce(refreshCount = 2, event = HomeFeatureEvent.RefreshClicked))
    }
}
