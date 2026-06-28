package studio.mekate.mobi.nearbyvehiclemap

import android.os.Parcel
import android.os.Parcelable
import com.slack.circuit.runtime.CircuitUiState
import com.slack.circuit.runtime.screen.Screen
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState
import studio.mekate.mobi.feature.nearbyvehiclemap.RiderLocationBlockedReason

data object NearbyVehicleMapScreen : Screen {
    override fun describeContents(): Int = 0

    override fun writeToParcel(
        parcel: Parcel,
        flags: Int,
    ) = Unit

    @JvmField
    val CREATOR: Parcelable.Creator<NearbyVehicleMapScreen> =
        object : Parcelable.Creator<NearbyVehicleMapScreen> {
            override fun createFromParcel(parcel: Parcel): NearbyVehicleMapScreen = NearbyVehicleMapScreen

            override fun newArray(size: Int): Array<NearbyVehicleMapScreen?> = arrayOfNulls(size)
        }
}

data class NearbyVehicleMapScreenState(
    val featureState: NearbyVehicleMapFeatureState,
    val eventSink: (NearbyVehicleMapScreenEvent) -> Unit,
) : CircuitUiState

sealed interface NearbyVehicleMapScreenEvent {
    data class PreciseLocationResolved(
        val location: RiderLocation,
    ) : NearbyVehicleMapScreenEvent

    data class LocationAccessBlocked(
        val reason: RiderLocationBlockedReason,
    ) : NearbyVehicleMapScreenEvent

    data object LocationTemporarilyUnavailable : NearbyVehicleMapScreenEvent

    data class VisibleRefreshDue(
        val nowMillis: Long,
    ) : NearbyVehicleMapScreenEvent

    data class ManualRefreshRequested(
        val nowMillis: Long,
    ) : NearbyVehicleMapScreenEvent
}
