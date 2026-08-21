package studio.mekate.mobi.nearbyvehiclemap

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason

object AndroidNearbyVehicleLocationResolver {
    val locationPermissions: Array<String> =
        arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )

    fun resolveCurrentLocation(context: Context): AndroidNearbyVehicleLocationResult {
        val hasFineLocation = context.hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val hasCoarseLocation = context.hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)

        return when {
            hasFineLocation -> {
                context.preciseLocationResult()
            }

            hasCoarseLocation -> {
                AndroidNearbyVehicleLocationResult.Blocked(RiderLocationBlockedReason.ApproximateOnly)
            }

            else -> {
                AndroidNearbyVehicleLocationResult.PermissionRequired
            }
        }
    }

    fun resolvePermissionResult(
        context: Context,
        grants: Map<String, Boolean>,
    ): AndroidNearbyVehicleLocationResult {
        val fineGranted = grants[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarseGranted = grants[Manifest.permission.ACCESS_COARSE_LOCATION] == true

        return when {
            fineGranted -> context.preciseLocationResult()
            coarseGranted -> AndroidNearbyVehicleLocationResult.Blocked(RiderLocationBlockedReason.ApproximateOnly)
            else -> AndroidNearbyVehicleLocationResult.Blocked(RiderLocationBlockedReason.AccessDenied)
        }
    }

    private fun Context.preciseLocationResult(): AndroidNearbyVehicleLocationResult {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val provider = locationManager?.enabledProvider()

        return if (locationManager == null || provider == null) {
            AndroidNearbyVehicleLocationResult.Blocked(RiderLocationBlockedReason.ServicesDisabled)
        } else {
            locationManager.lastKnownLocationResult(provider)
        }
    }

    private fun LocationManager.enabledProvider(): String? =
        when {
            isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> null
        }

    // Permission can be revoked between the explicit check and the platform API call.
    @Suppress("SwallowedException")
    private fun LocationManager.lastKnownLocationResult(provider: String): AndroidNearbyVehicleLocationResult =
        try {
            getLastKnownLocation(provider)?.toResult()
                ?: AndroidNearbyVehicleLocationResult.TemporarilyUnavailable
        } catch (error: SecurityException) {
            AndroidNearbyVehicleLocationResult.Blocked(RiderLocationBlockedReason.AccessDenied)
        }

    private fun Location.toResult(): AndroidNearbyVehicleLocationResult =
        AndroidNearbyVehicleLocationResult.Resolved(
            RiderLocation(
                latitude = latitude,
                longitude = longitude,
            ),
        )

    private fun Context.hasPermission(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
}

internal fun AndroidNearbyVehicleLocationResult.toScreenEvent(): NearbyVehicleMapScreenEvent =
    when (this) {
        AndroidNearbyVehicleLocationResult.PermissionRequired -> {
            NearbyVehicleMapScreenEvent.LocationAccessBlocked(
                reason = RiderLocationBlockedReason.AccessDenied,
            )
        }

        is AndroidNearbyVehicleLocationResult.Resolved -> {
            NearbyVehicleMapScreenEvent.PreciseLocationResolved(location = location)
        }

        is AndroidNearbyVehicleLocationResult.Blocked -> {
            NearbyVehicleMapScreenEvent.LocationAccessBlocked(reason = reason)
        }

        AndroidNearbyVehicleLocationResult.TemporarilyUnavailable -> {
            NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable
        }
    }

sealed interface AndroidNearbyVehicleLocationResult {
    data object PermissionRequired : AndroidNearbyVehicleLocationResult

    data class Resolved(
        val location: RiderLocation,
    ) : AndroidNearbyVehicleLocationResult

    data class Blocked(
        val reason: RiderLocationBlockedReason,
    ) : AndroidNearbyVehicleLocationResult

    data object TemporarilyUnavailable : AndroidNearbyVehicleLocationResult
}
