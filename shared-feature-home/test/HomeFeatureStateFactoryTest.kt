package studio.mekate.b3.feature.home

import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HomeFeatureStateFactoryTest {
    @Test
    fun `should have initial shared state when counter value is zero`() {
        // given
        val factory = createStateFactory()

        // when
        val state = factory.create(
            counterValue = 0,
            isLoading = false,
        )

        // then
        assertEquals("Native shell, shared feature", state.title)
        assertEquals("Shared feature state flowing into the TestOS shell.", state.message)
        assertEquals("Load next counter value", state.primaryActionLabel)
        assertEquals(0, state.counterValue)
        assertEquals(false, state.isLoading)
        assertTrue(state.supportingText.contains("shared-core"))
    }

    @Test
    fun `should have loading shared state when counter refresh is in progress`() {
        // given
        val factory = createStateFactory()

        // when
        val state = factory.create(
            counterValue = 3,
            isLoading = true,
        )

        // then
        assertEquals(3, state.counterValue)
        assertTrue(state.isLoading)
        assertTrue(state.supportingText.contains("Loading the next fibonacci counter value"))
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
