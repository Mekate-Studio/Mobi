package studio.mekate.b3.feature.home

import kotlinx.coroutines.test.runTest
import studio.mekate.b3.core.FakeCounterRepository
import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class HomeFeatureServiceTest {
    @Test
    fun `should have loading shared state when refresh is in progress`() {
        // given
        val service = createService()

        // when
        val state = service.loadingState(counterValue = 2)

        // then
        assertEquals(2, state.counterValue)
        assertTrue(state.isLoading)
        assertEquals(
            "Loading the next fibonacci counter value from the fake repository for the TestOS shell.",
            state.supportingText,
        )
    }

    @Test
    fun `should have next fibonacci shared state when refresh is completed`() = runTest {
        // given
        val service = createService()

        // when
        val state = service.refresh(counterValue = 2)

        // then
        assertEquals(3, state.counterValue)
        assertFalse(state.isLoading)
        assertEquals(
            "The fake repository returned fibonacci counter value 3 for the TestOS shell.",
            state.supportingText,
        )
    }

    private fun createService(
        platformName: String = "TestOS",
    ): HomeFeatureService {
        return HomeFeatureService(
            stateFactory = HomeFeatureStateFactory(
                platformContextProvider = PlatformContextProvider(
                    platformNameProvider = PlatformNameProvider { platformName },
                ),
            ),
            counterRepository = FakeCounterRepository(),
        )
    }
}
