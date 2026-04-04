package studio.mekate.b3.feature.home

import kotlinx.coroutines.test.runTest
import studio.mekate.b3.core.FakeCounterRepository
import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.core.CounterRepositoryException
import studio.mekate.b3.core.CounterRequestFailurePolicy
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class HomeFeatureServiceTest {
    @Test
    fun `should have loading loadable state when refresh is in progress`() {
        // given
        val service = createService(shouldFail = false)

        // when
        val state = service.loadingState(counterValue = 2)

        // then
        val loading = assertIs<CounterLoadable.Loading>(state.counterLoadable)
        assertEquals(2, loading.previousValue)
        assertEquals(
            "Loading the next fibonacci counter value from the fake repository for the TestOS shell.",
            state.supportingText,
        )
    }

    @Test
    fun `should have loaded loadable state when refresh succeeds`() = runTest {
        // given
        val service = createService(shouldFail = false)

        // when
        val state = service.refresh(counterValue = 2)

        // then
        val loaded = assertIs<CounterLoadable.Loaded>(state.counterLoadable)
        assertEquals(3, loaded.value)
        assertEquals(
            "The fake repository returned fibonacci counter value 3 for the TestOS shell.",
            state.supportingText,
        )
    }

    @Test
    fun `should have error loadable state when refresh fails`() = runTest {
        // given
        val service = createService(shouldFail = true)

        // when
        val state = service.refresh(counterValue = 2)

        // then
        val error = assertIs<CounterLoadable.Error>(state.counterLoadable)
        assertEquals(2, error.previousValue)
        assertEquals(CounterRepositoryException.DEFAULT_MESSAGE, error.message)
        assertEquals(
            "${CounterRepositoryException.DEFAULT_MESSAGE} Showing last known counter value 2 in the TestOS shell.",
            state.supportingText,
        )
    }

    private fun createService(
        platformName: String = "TestOS",
        shouldFail: Boolean,
    ): HomeFeatureService {
        return HomeFeatureService(
            stateFactory = HomeFeatureStateFactory(
                platformContextProvider = PlatformContextProvider(
                    platformNameProvider = PlatformNameProvider { platformName },
                ),
            ),
            counterRepository = FakeCounterRepository(
                failurePolicy = object : CounterRequestFailurePolicy {
                    override fun shouldFail(
                        currentCounterValue: Int,
                    ): Boolean = shouldFail
                },
            ),
        )
    }
}
