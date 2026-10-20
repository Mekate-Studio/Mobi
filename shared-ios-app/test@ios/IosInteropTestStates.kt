package studio.mekate.mobi.ios.test

import studio.mekate.mobi.core.FleetSnapshot
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFailureReason
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState

object IosInteropTestStates {
    // IOS-15: generated nested case aliases are internal in Kotlin 2.4.20.
    // These test-only constructors disappear when public aliases compile in Swift.
    val riderResolving: RiderLocationState get() = RiderLocationState.Resolving

    fun riderAvailable(location: RiderLocation): RiderLocationState = RiderLocationState.Available(location)

    val riderDenied: RiderLocationState get() = RiderLocationState.Denied

    fun riderBlocked(reason: RiderLocationBlockedReason): RiderLocationState = RiderLocationState.Blocked(reason)

    fun riderTemporarilyUnavailable(location: RiderLocation): RiderLocationState =
        RiderLocationState.TemporarilyUnavailable(location)

    val snapshotInitial: NearbyVehicleSnapshotState get() = NearbyVehicleSnapshotState.Initial

    val snapshotLoading: NearbyVehicleSnapshotState get() = NearbyVehicleSnapshotState.Loading

    fun snapshotLoaded(snapshot: FleetSnapshot): NearbyVehicleSnapshotState =
        NearbyVehicleSnapshotState.Loaded(snapshot)

    fun snapshotRefreshing(snapshot: FleetSnapshot): NearbyVehicleSnapshotState =
        NearbyVehicleSnapshotState.Refreshing(snapshot)

    fun snapshotFailedWithout(reason: NearbyVehicleMapFailureReason): NearbyVehicleSnapshotState =
        NearbyVehicleSnapshotState.FailedWithoutSnapshot(reason)

    val overlayNone: NearbyVehicleMapOverlayState get() = NearbyVehicleMapOverlayState.None

    val overlayRefreshing: NearbyVehicleMapOverlayState get() = NearbyVehicleMapOverlayState.RefreshingIndicator

    val overlayBlocking: NearbyVehicleMapOverlayState get() = NearbyVehicleMapOverlayState.BlockingFailure
}
