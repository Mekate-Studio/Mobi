package studio.mekate.mobi.core

import dev.zacsweers.metro.Inject
import kotlinx.coroutines.delay
import kotlin.time.Duration.Companion.milliseconds

data class NearbyFleetRequest(
    val riderLocation: RiderLocation,
    val requestedAtMillis: Long,
)

interface NearbyFleetRepository {
    suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot
}

class NearbyFleetRepositoryException(
    message: String = DEFAULT_MESSAGE,
) : RuntimeException(message) {
    companion object {
        const val DEFAULT_MESSAGE = "The simulated fleet repository failed to load nearby vehicles."
    }
}

fun interface NearbyFleetFailurePolicy {
    fun shouldFail(request: NearbyFleetRequest): Boolean
}

@Inject
class NeverFailNearbyFleetFailurePolicy : NearbyFleetFailurePolicy {
    override fun shouldFail(request: NearbyFleetRequest): Boolean = false
}

@Inject
class SimulatedNearbyFleetRepository(
    private val failurePolicy: NearbyFleetFailurePolicy,
) : NearbyFleetRepository {
    private var nextSnapshotIndex = 0

    override suspend fun fetchNearbyFleetSnapshot(request: NearbyFleetRequest): FleetSnapshot {
        delay(API_DELAY_MILLIS.milliseconds)
        if (failurePolicy.shouldFail(request)) {
            throw NearbyFleetRepositoryException()
        }

        val snapshotTemplate = snapshotTemplates[nextSnapshotIndex % snapshotTemplates.size]
        nextSnapshotIndex += 1

        return FleetSnapshot(
            sequence = nextSnapshotIndex.toLong(),
            riderLocation = request.riderLocation,
            vehicles = snapshotTemplate,
            loadedAtMillis = request.requestedAtMillis,
        )
    }

    companion object {
        const val API_DELAY_MILLIS: Long = 150

        val snapshotTemplates: List<List<NearbyVehicle>> =
            listOf(
                listOf(
                    NearbyVehicle(
                        id = VehicleId("mobi-001"),
                        location = VehicleLocation(latitude = 55.6763, longitude = 12.5681),
                    ),
                    NearbyVehicle(
                        id = VehicleId("mobi-002"),
                        location = VehicleLocation(latitude = 55.6780, longitude = 12.5712),
                    ),
                ),
                listOf(
                    NearbyVehicle(
                        id = VehicleId("mobi-001"),
                        location = VehicleLocation(latitude = 55.6768, longitude = 12.5690),
                    ),
                    NearbyVehicle(
                        id = VehicleId("mobi-003"),
                        location = VehicleLocation(latitude = 55.6742, longitude = 12.5655),
                    ),
                ),
                emptyList(),
            )
    }
}
