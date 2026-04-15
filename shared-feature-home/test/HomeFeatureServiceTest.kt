package studio.mekate.b3.feature.home

import kotlinx.coroutines.test.runTest
import studio.mekate.b3.core.FakeCounterRepository
import studio.mekate.b3.core.CounterRepositoryException
import studio.mekate.b3.core.CounterRepository
import studio.mekate.b3.core.CounterRequestFailurePolicy
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class HomeFeatureServiceTest {
    @Test
    fun `should have initial loadable state when feature has not loaded a counter value`() {
        // given
        val service = createService(shouldFail = false)

        // when
        val state = service.initialState()

        // then
        assertIs<CounterLoadable.Initial>(state.counterLoadable)
    }

    @Test
    fun `should have loading loadable state when refresh is in progress`() {
        // given
        val service = createService(shouldFail = false)

        // when
        val state = service.loadingState(counterValue = 2)

        // then
        val loading = assertIs<CounterLoadable.Loading>(state.counterLoadable)
        assertEquals(2, loading.previousValue)
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
    }

    @Test
    fun `should have generic error loadable state when refresh fails unexpectedly`() = runTest {
        // given
        val service = HomeFeatureService(
            counterRepository = object : CounterRepository {
                override suspend fun fetchNextCounterValue(
                    currentCounterValue: Int,
                ): Int {
                    error("Boom")
                }
            },
        )

        // when
        val state = service.refresh(counterValue = 2)

        // then
        val error = assertIs<CounterLoadable.Error>(state.counterLoadable)
        assertEquals(2, error.previousValue)
        assertEquals(HomeFeatureService.DEFAULT_UNEXPECTED_REFRESH_ERROR_MESSAGE, error.message)
    }

    private fun createService(
        shouldFail: Boolean,
    ): HomeFeatureService {
        return HomeFeatureService(
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
