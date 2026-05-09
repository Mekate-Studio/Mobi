package studio.mekate.mobi.core

import dev.zacsweers.metro.Inject
import kotlinx.coroutines.delay
import kotlin.random.Random
import kotlin.time.Duration.Companion.milliseconds

interface CounterRepository {
    suspend fun fetchNextCounterValue(currentCounterValue: Int): Int
}

interface CounterRequestFailurePolicy {
    fun shouldFail(currentCounterValue: Int): Boolean
}

@Inject
class RandomCounterRequestFailurePolicy : CounterRequestFailurePolicy {
    override fun shouldFail(currentCounterValue: Int): Boolean = Random.nextInt(100) < FAILURE_PERCENTAGE

    internal companion object {
        const val FAILURE_PERCENTAGE = 35
    }
}

class CounterRepositoryException(
    message: String = DEFAULT_MESSAGE,
) : RuntimeException(message) {
    companion object {
        const val DEFAULT_MESSAGE = "The fake repository failed to load the next fibonacci counter value."
    }
}

@Inject
class FakeCounterRepository(
    private val failurePolicy: CounterRequestFailurePolicy,
) : CounterRepository {
    override suspend fun fetchNextCounterValue(currentCounterValue: Int): Int {
        delay(API_DELAY_MILLIS.milliseconds)
        if (failurePolicy.shouldFail(currentCounterValue)) {
            throw CounterRepositoryException()
        }
        return nextFibonacciValueAfter(currentCounterValue)
    }

    companion object {
        const val API_DELAY_MILLIS: Long = 150

        fun nextFibonacciValueAfter(currentCounterValue: Int): Int {
            if (currentCounterValue < 1) return 1

            var previous = 0
            var current = 1

            while (current <= currentCounterValue) {
                val next = previous + current
                previous = current
                current = next
            }

            return current
        }
    }
}
