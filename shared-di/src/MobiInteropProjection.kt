package studio.mekate.mobi.di

import studio.mekate.mobi.feature.home.CounterLoadFailureReason
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapOverlayState
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleSnapshotState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationState

// Explicit typed Swift boundary; shared domain states remain unchanged.

interface MobiCounterVisitor {
    fun onInitial()

    fun onLoading(value: CounterLoadable.Loading)

    fun onLoaded(value: CounterLoadable.Loaded)

    fun onError(value: CounterLoadable.Error)
}

interface MobiCounterFailureVisitor {
    fun onRepositoryUnavailable()

    fun onUnexpected()
}

interface MobiRiderLocationVisitor {
    fun onResolving()

    fun onAvailable(value: RiderLocationState.Available)

    fun onDenied()

    fun onBlocked(value: RiderLocationState.Blocked)

    fun onTemporarilyUnavailable(value: RiderLocationState.TemporarilyUnavailable)

    fun onUnavailable()
}

interface MobiSnapshotVisitor {
    fun onInitial()

    fun onLoading()

    fun onSnapshotLoaded(value: NearbyVehicleSnapshotState.Loaded)

    fun onRefreshing(value: NearbyVehicleSnapshotState.Refreshing)

    fun onFailedWithSnapshot(value: NearbyVehicleSnapshotState.FailedWithSnapshot)

    fun onFailedWithoutSnapshot(value: NearbyVehicleSnapshotState.FailedWithoutSnapshot)
}

interface MobiOverlayVisitor {
    fun onNone()

    fun onRefreshingIndicator()

    fun onStaleIndicator()

    fun onBlockingFailure()
}

interface MobiRiderReasonVisitor {
    fun onAccessDenied()

    fun onAccessRestricted()

    fun onServicesDisabled()

    fun onApproximateOnly()

    fun onTemporarilyUnavailable()
}

object MobiInteropProjection {
    fun counter(
        state: CounterLoadable,
        visitor: MobiCounterVisitor,
    ) {
        when (state) {
            CounterLoadable.Initial -> visitor.onInitial()
            is CounterLoadable.Loading -> visitor.onLoading(state)
            is CounterLoadable.Loaded -> visitor.onLoaded(state)
            is CounterLoadable.Error -> visitor.onError(state)
        }
    }

    fun counterFailure(
        state: CounterLoadFailureReason,
        visitor: MobiCounterFailureVisitor,
    ) {
        when (state) {
            CounterLoadFailureReason.RepositoryUnavailable -> visitor.onRepositoryUnavailable()
            CounterLoadFailureReason.Unexpected -> visitor.onUnexpected()
        }
    }

    fun riderLocation(
        state: RiderLocationState,
        visitor: MobiRiderLocationVisitor,
    ) {
        when (state) {
            RiderLocationState.Resolving -> visitor.onResolving()
            is RiderLocationState.Available -> visitor.onAvailable(state)
            RiderLocationState.Denied -> visitor.onDenied()
            is RiderLocationState.Blocked -> visitor.onBlocked(state)
            is RiderLocationState.TemporarilyUnavailable -> visitor.onTemporarilyUnavailable(state)
            RiderLocationState.Unavailable -> visitor.onUnavailable()
        }
    }

    fun snapshot(
        state: NearbyVehicleSnapshotState,
        visitor: MobiSnapshotVisitor,
    ) {
        when (state) {
            NearbyVehicleSnapshotState.Initial -> visitor.onInitial()
            NearbyVehicleSnapshotState.Loading -> visitor.onLoading()
            is NearbyVehicleSnapshotState.Loaded -> visitor.onSnapshotLoaded(state)
            is NearbyVehicleSnapshotState.Refreshing -> visitor.onRefreshing(state)
            is NearbyVehicleSnapshotState.FailedWithSnapshot -> visitor.onFailedWithSnapshot(state)
            is NearbyVehicleSnapshotState.FailedWithoutSnapshot -> visitor.onFailedWithoutSnapshot(state)
        }
    }

    fun overlay(
        state: NearbyVehicleMapOverlayState,
        visitor: MobiOverlayVisitor,
    ) {
        when (state) {
            NearbyVehicleMapOverlayState.None -> visitor.onNone()
            NearbyVehicleMapOverlayState.RefreshingIndicator -> visitor.onRefreshingIndicator()
            NearbyVehicleMapOverlayState.StaleIndicator -> visitor.onStaleIndicator()
            NearbyVehicleMapOverlayState.BlockingFailure -> visitor.onBlockingFailure()
        }
    }

    fun riderReason(
        state: RiderLocationBlockedReason,
        visitor: MobiRiderReasonVisitor,
    ) {
        when (state) {
            RiderLocationBlockedReason.AccessDenied -> visitor.onAccessDenied()
            RiderLocationBlockedReason.AccessRestricted -> visitor.onAccessRestricted()
            RiderLocationBlockedReason.ServicesDisabled -> visitor.onServicesDisabled()
            RiderLocationBlockedReason.ApproximateOnly -> visitor.onApproximateOnly()
            RiderLocationBlockedReason.TemporarilyUnavailable -> visitor.onTemporarilyUnavailable()
        }
    }
}
