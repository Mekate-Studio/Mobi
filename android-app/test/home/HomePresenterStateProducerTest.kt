package studio.mekate.b3.home

import studio.mekate.b3.core.PlatformContextProvider
import studio.mekate.b3.core.PlatformNameProvider
import studio.mekate.b3.feature.home.HomeFeatureStateFactory
import kotlin.test.Test
import kotlin.test.assertEquals

class HomePresenterStateProducerTest {
    private val producer = HomePresenterStateProducer(
        stateFactory = HomeFeatureStateFactory(
            platformContextProvider = PlatformContextProvider(
                platformNameProvider = PlatformNameProvider { "TestOS" },
            ),
        ),
    )

    @Test
    fun createsInitialStateAndRefreshTransition() {
        var refreshCount = 0

        val initialState = producer.create(refreshCount = refreshCount) { updatedRefreshCount ->
            refreshCount = updatedRefreshCount
        }
        assertEquals("Native shell, shared feature", initialState.featureState.title)
        assertEquals("Shared feature state flowing into the TestOS shell.", initialState.featureState.message)
        assertEquals(
            "shared-core exposes platform context, shared-feature-home turns it into feature state, and platform shells decide how to render it.",
            initialState.featureState.supportingText,
        )
        assertEquals(0, initialState.featureState.refreshCount)

        initialState.eventSink(HomeScreenEvent.RefreshClicked)
        assertEquals(1, refreshCount)

        val refreshedState = producer.create(refreshCount = refreshCount) { updatedRefreshCount ->
            refreshCount = updatedRefreshCount
        }
        assertEquals(1, refreshedState.featureState.refreshCount)
        assertEquals(
            "The shared reducer has already handled one refresh for the TestOS shell.",
            refreshedState.featureState.supportingText,
        )
    }
}
