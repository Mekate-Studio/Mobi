package studio.mekate.b3.di

import studio.mekate.b3.core.PlatformNameProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SharedDependenciesTest {
    @Test
    fun createsHomeFeatureStateFactoryFromGraph() {
        val stateFactory = SharedDependencies.createHomeFeatureStateFactory(
            platformNameProvider = PlatformNameProvider { "TestOS" },
        )

        val state = stateFactory.create(refreshCount = 0)

        assertEquals("Shared feature state flowing into the TestOS shell.", state.message)
        assertTrue(state.supportingText.contains("shared-core"))
    }
}
