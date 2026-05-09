package studio.mekate.mobi.core

import kotlin.jvm.JvmInline

@JvmInline
value class VehicleId(
    val value: String,
) {
    init {
        require(value.isNotBlank()) { "Vehicle identity must not be blank." }
    }
}

data class VehicleLocation(
    val latitude: Double,
    val longitude: Double,
) {
    init {
        require(latitude in MIN_LATITUDE..MAX_LATITUDE) { "Vehicle latitude must be between -90 and 90." }
        require(longitude in MIN_LONGITUDE..MAX_LONGITUDE) { "Vehicle longitude must be between -180 and 180." }
    }
}

data class RiderLocation(
    val latitude: Double,
    val longitude: Double,
) {
    init {
        require(latitude in MIN_LATITUDE..MAX_LATITUDE) { "Rider latitude must be between -90 and 90." }
        require(longitude in MIN_LONGITUDE..MAX_LONGITUDE) { "Rider longitude must be between -180 and 180." }
    }
}

data class NearbyVehicle(
    val id: VehicleId,
    val location: VehicleLocation,
)

data class FleetSnapshot(
    val sequence: Long,
    val riderLocation: RiderLocation,
    val vehicles: List<NearbyVehicle>,
    val loadedAtMillis: Long,
) {
    init {
        require(sequence >= 0) { "Fleet snapshot sequence must not be negative." }
        require(loadedAtMillis >= 0) { "Fleet snapshot load time must not be negative." }
    }

    val isEmpty: Boolean = vehicles.isEmpty()
}

private const val MIN_LATITUDE = -90.0
private const val MAX_LATITUDE = 90.0
private const val MIN_LONGITUDE = -180.0
private const val MAX_LONGITUDE = 180.0
