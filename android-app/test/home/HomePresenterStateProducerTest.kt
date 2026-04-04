package studio.mekate.b3.home

import kotlinx.coroutines.test.runTest
import studio.mekate.b3.core.FakeCounterRepository
import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.feature.home.HomeFeatureService
import studio.mekate.b3.feature.home.HomeFeatureStateFactory
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class HomePresenterStateProducerTest {
    @Test
    fun `should have initial presenter state when feature is first created`() {
        // given
        val producer = createStateProducer()

        // when
        val initialState = producer.initialState()

        // then
        assertEquals("Native shell, shared feature", initialState.title)
        assertEquals("Shared feature state flowing into the TestOS shell.", initialState.message)
        assertEquals(
            "shared-core exposes platform context, shared-feature-home fetches counter values from a fake repository, and platform shells decide how to render them.",
            initialState.supportingText,
        )
        assertEquals(0, initialState.counterValue)
        assertFalse(initialState.isLoading)
    }

    @Test
    fun `should request refresh for current counter value when refresh event is sent`() {
        // given
        val producer = createStateProducer()
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
    fun `should have refreshed presenter state when refresh is completed`() = runTest {
        // given
        val producer = createStateProducer()

        // when
        val loadingState = producer.loadingState(counterValue = 0)
        val refreshedState = producer.refreshedState(counterValue = 0)

        // then
        assertEquals(0, loadingState.counterValue)
        assertTrue(loadingState.isLoading)
        assertEquals(1, refreshedState.counterValue)
        assertFalse(refreshedState.isLoading)
        assertEquals(
            "The fake repository returned fibonacci counter value 1 for the TestOS shell.",
            refreshedState.supportingText,
        )
    }

    private fun createStateProducer(
        platformName: String = "TestOS",
    ): HomePresenterStateProducer {
        return HomePresenterStateProducer(
            service = HomeFeatureService(
                stateFactory = HomeFeatureStateFactory(
                    platformContextProvider = PlatformContextProvider(
                        platformNameProvider = PlatformNameProvider { platformName },
                    ),
                ),
                counterRepository = FakeCounterRepository(),
            ),
        )
    }
}
