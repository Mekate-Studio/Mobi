package studio.mekate.mobi.ui.home

import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithText
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.job
import org.junit.Rule
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import studio.mekate.mobi.core.CounterRepository
import studio.mekate.mobi.feature.home.HomeFeatureService
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [36])
class SharedHomeAdmissionTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    @Test
    fun shouldAdmitOneQueuedRefreshAndUseCurrentValueAfterCompletion() {
        // given
        val repository = ControlledCounterRepository()
        val service = HomeFeatureService(repository)
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        try {
            controller.get().setContent { SharedHomeScreen(service) }
            val refresh =
                requireNotNull(
                    compose
                        .onNodeWithText(
                            "Load next counter value",
                        ).fetchSemanticsNode()
                        .config[SemanticsActions.OnClick]
                        .action,
                )

            // when: both callbacks arrive before queued refresh work runs.
            compose.runOnIdle {
                assertTrue(refresh())
                assertTrue(refresh())
            }
            compose.waitForIdle()

            // then
            val first = repository.requests.tryReceive().getOrThrow()
            assertEquals(0, first.currentValue)
            assertTrue(repository.requests.tryReceive().isFailure, "A queued duplicate must not start another request")
            compose.onNodeWithText("Loading…").assertIsNotEnabled()
            compose.runOnIdle { refresh() }
            compose.waitForIdle()
            assertTrue(repository.requests.tryReceive().isFailure, "A busy callback must not start another request")
            compose.runOnIdle { first.response.complete(Result.success(8)) }
            compose.onNodeWithText("Counter value: 8").assertExists()

            // A retained callback carries intent, rather than an obsolete counter.
            compose.runOnIdle { refresh() }
            compose.waitForIdle()
            val next = repository.requests.tryReceive().getOrThrow()
            assertEquals(8, next.currentValue)
            assertTrue(repository.requests.tryReceive().isFailure)
            compose.runOnIdle { next.response.complete(Result.success(13)) }
            compose.onNodeWithText("Counter value: 13").assertExists()
        } finally {
            controller.pause().stop().destroy()
        }
    }
}

private data class PendingCounterRequest(
    val currentValue: Int,
    val response: CompletableDeferred<Result<Int>>,
)

private class ControlledCounterRepository : CounterRepository {
    val requests = Channel<PendingCounterRequest>(Channel.UNLIMITED)

    override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int {
        val response = CompletableDeferred<Result<Int>>(currentCoroutineContext().job)
        requests.send(PendingCounterRequest(currentCounterValue, response))
        return response.await().getOrThrow()
    }
}
