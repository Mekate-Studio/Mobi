package studio.mekate.b3.feature.home

import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.core.CounterRepositoryException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

class HomeFeatureStateFactoryTest {
    @Test
    fun `should have initial loadable state when feature has not loaded a counter value`() {
        // given
        val factory = createStateFactory()

        // when
        val state = factory.create(
            counterLoadable = CounterLoadable.Initial,
        )

        // then
        assertEquals("Native shell, shared feature", state.title)
        assertEquals("Shared feature state flowing into the TestOS shell.", state.message)
        assertEquals("Load next counter value", state.primaryActionLabel)
        assertIs<CounterLoadable.Initial>(state.counterLoadable)
        assertTrue(state.supportingText.contains("shared-core"))
    }

    @Test
    fun `should have loading loadable state when counter refresh is in progress`() {
        // given
        val factory = createStateFactory()

        // when
        val state = factory.create(
            counterLoadable = CounterLoadable.Loading(previousValue = 3),
        )

        // then
        assertIs<CounterLoadable.Loading>(state.counterLoadable)
        assertTrue(state.supportingText.contains("Loading the next fibonacci counter value"))
    }

    @Test
    fun `should have error loadable state when repository load fails after a previous counter value`() {
        // given
        val factory = createStateFactory()

        // when
        val state = factory.create(
            counterLoadable = CounterLoadable.Error(
                previousValue = 5,
                message = CounterRepositoryException.DEFAULT_MESSAGE,
            ),
        )

        // then
        val error = assertIs<CounterLoadable.Error>(state.counterLoadable)
        assertEquals(5, error.previousValue)
        assertTrue(state.supportingText.contains("Showing last known counter value 5"))
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
