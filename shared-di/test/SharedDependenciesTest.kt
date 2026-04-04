package studio.mekate.b3.di

import studio.mekate.b3.core.PlatformNameProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SharedDependenciesTest {
    @Test
    fun `should create home feature service from graph when platform provider is supplied`() {
        // given
        val service = SharedDependencies.createHomeFeatureService(
            platformNameProvider = PlatformNameProvider { "TestOS" },
        )

        // when
        val state = service.initialState()

        // then
        assertEquals("Shared feature state flowing into the TestOS shell.", state.message)
        assertTrue(state.supportingText.contains("shared-core"))
    }
}
