package studio.mekate.mobi.core

data class NearbyVehicleMapOffset(
    val x: Double,
    val y: Double,
)

object NearbyVehicleMapProjection {
    fun offset(
        vehicleLocation: VehicleLocation,
        riderLocation: RiderLocation,
    ): NearbyVehicleMapOffset =
        NearbyVehicleMapOffset(
            x = (vehicleLocation.longitude - riderLocation.longitude) * LONGITUDE_SCALE,
            y = (vehicleLocation.latitude - riderLocation.latitude) * LATITUDE_SCALE,
        )

    private const val LATITUDE_SCALE = 1_000.0
    private const val LONGITUDE_SCALE = 1_800.0
}
