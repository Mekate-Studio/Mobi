package studio.mekate.mobi.core

import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class FakeCounterRepositoryTest {
    @Test
    fun `should return first fibonacci counter value when request succeeds from zero`() =
        runTest {
            // given
            val repository = createRepository(shouldFail = false)

            // when
            val nextCounterValue = repository.fetchNextCounterValue(currentCounterValue = 0)

            // then
            assertEquals(1, nextCounterValue)
            assertEquals(FakeCounterRepository.API_DELAY_MILLIS, currentTime)
        }

    @Test
    fun `should return next fibonacci counter value when request succeeds from first fibonacci value`() =
        runTest {
            // given
            val repository = createRepository(shouldFail = false)

            // when
            val nextCounterValue = repository.fetchNextCounterValue(currentCounterValue = 1)

            // then
            assertEquals(2, nextCounterValue)
            assertEquals(FakeCounterRepository.API_DELAY_MILLIS, currentTime)
        }

    @Test
    fun `should return next fibonacci counter value when request succeeds from later fibonacci value`() =
        runTest {
            // given
            val repository = createRepository(shouldFail = false)

            // when
            val nextCounterValue = repository.fetchNextCounterValue(currentCounterValue = 3)

            // then
            assertEquals(5, nextCounterValue)
            assertEquals(FakeCounterRepository.API_DELAY_MILLIS, currentTime)
        }

    @Test
    fun `should throw repository exception when failure policy requests failure`() =
        runTest {
            // given
            val repository = createRepository(shouldFail = true)

            // when
            val error =
                assertFailsWith<CounterRepositoryException> {
                    repository.fetchNextCounterValue(currentCounterValue = 3)
                }

            // then
            assertEquals(CounterRepositoryException.DEFAULT_MESSAGE, error.message)
            assertEquals(FakeCounterRepository.API_DELAY_MILLIS, currentTime)
        }

    private fun createRepository(shouldFail: Boolean): FakeCounterRepository =
        FakeCounterRepository(
            failurePolicy =
                object : CounterRequestFailurePolicy {
                    override fun shouldFail(currentCounterValue: Int): Boolean = shouldFail
                },
        )
}
