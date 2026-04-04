package studio.mekate.b3.home

import kotlinx.coroutines.test.runTest
import studio.mekate.b3.core.FakeCounterRepository
import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.core.CounterRequestFailurePolicy
import studio.mekate.b3.feature.home.HomeFeatureService
import studio.mekate.b3.feature.home.CounterLoadable
import studio.mekate.b3.feature.home.HomeFeatureStateFactory
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class HomePresenterStateProducerTest {
    @Test
    fun `should have initial presenter state when feature is first created`() {
        // given
        val producer = createStateProducer(shouldFail = false)

        // when
        val initialState = producer.initialState()

        // then
        assertEquals("Native shell, shared feature", initialState.title)
        assertEquals("Shared feature state flowing into the TestOS shell.", initialState.message)
        assertEquals(
            "shared-core exposes platform context, shared-feature-home fetches counter values from a fake repository, and platform shells decide how to render them.",
            initialState.supportingText,
        )
        assertIs<CounterLoadable.Initial>(initialState.counterLoadable)
    }

    @Test
    fun `should request refresh for current counter value when refresh event is sent`() {
        // given
        val producer = createStateProducer(shouldFail = false)
        var requestedCounterValue = -1
        val homeScreenState = producer.create(featureState = producer.initialState()) { counterValue ->
            requestedCounterValue = counterValue
        }

        // when
        homeScreenState.eventSink(HomeScreenEvent.RefreshClicked)

        // then
        assertEquals(0, requestedCounterValue)
    }

    @Test
    fun `should have loading and loaded presenter states when refresh succeeds`() = runTest {
        // given
        val producer = createStateProducer(shouldFail = false)

        // when
        val loadingState = producer.loadingState(counterValue = 0)
        val refreshedState = producer.refreshedState(counterValue = 0)

        // then
        assertIs<CounterLoadable.Loading>(loadingState.counterLoadable)
        val loaded = assertIs<CounterLoadable.Loaded>(refreshedState.counterLoadable)
        assertEquals(1, loaded.value)
        assertEquals(
            "The fake repository returned fibonacci counter value 1 for the TestOS shell.",
            refreshedState.supportingText,
        )
    }

    @Test
    fun `should have error presenter state when refresh fails`() = runTest {
        // given
        val producer = createStateProducer(shouldFail = true)

        // when
        val refreshedState = producer.refreshedState(counterValue = 1)

        // then
        val error = assertIs<CounterLoadable.Error>(refreshedState.counterLoadable)
        assertEquals(1, error.previousValue)
        assertEquals(
            "The fake repository failed to load the next fibonacci counter value. Showing last known counter value 1 in the TestOS shell.",
            refreshedState.supportingText,
        )
    }

    private fun createStateProducer(
        platformName: String = "TestOS",
        shouldFail: Boolean,
    ): HomePresenterStateProducer {
        return HomePresenterStateProducer(
            service = HomeFeatureService(
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
            ),
        )
    }
}
