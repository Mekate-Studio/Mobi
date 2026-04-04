package studio.mekate.b3.core

import dev.zacsweers.metro.Inject
import kotlinx.coroutines.delay

interface CounterRepository {
    suspend fun fetchNextCounterValue(
        currentCounterValue: Int,
    ): Int
}

@Inject
class FakeCounterRepository : CounterRepository {
    override suspend fun fetchNextCounterValue(
        currentCounterValue: Int,
    ): Int {
        delay(API_DELAY_MILLIS)
        return nextFibonacciValueAfter(currentCounterValue)
    }

    internal companion object {
        const val API_DELAY_MILLIS: Long = 150

        fun nextFibonacciValueAfter(
            currentCounterValue: Int,
        ): Int {
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
