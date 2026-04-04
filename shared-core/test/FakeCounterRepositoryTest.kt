package studio.mekate.b3.core

import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class FakeCounterRepositoryTest {
    @Test
    fun `should return first fibonacci counter value when current value is zero`() = runTest {
        // given
        val repository = FakeCounterRepository()

        // when
        val nextCounterValue = repository.fetchNextCounterValue(currentCounterValue = 0)

        // then
        assertEquals(1, nextCounterValue)
        assertEquals(FakeCounterRepository.API_DELAY_MILLIS, currentTime)
    }

    @Test
    fun `should return next fibonacci counter value when current value is already the first fibonacci value`() = runTest {
        // given
        val repository = FakeCounterRepository()

        // when
        val nextCounterValue = repository.fetchNextCounterValue(currentCounterValue = 1)

        // then
        assertEquals(2, nextCounterValue)
        assertEquals(FakeCounterRepository.API_DELAY_MILLIS, currentTime)
    }

    @Test
    fun `should return next fibonacci counter value when current value is already fibonacci`() = runTest {
        // given
        val repository = FakeCounterRepository()

        // when
        val nextCounterValue = repository.fetchNextCounterValue(currentCounterValue = 3)

        // then
        assertEquals(5, nextCounterValue)
        assertEquals(FakeCounterRepository.API_DELAY_MILLIS, currentTime)
    }
}
