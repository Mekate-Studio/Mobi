package studio.mekate.mobi.nearbyvehiclemap

import android.os.Parcel
import android.os.Parcelable
import com.slack.circuit.runtime.CircuitUiState
import com.slack.circuit.runtime.screen.Screen
import studio.mekate.mobi.feature.nearbyvehiclemap.NearbyVehicleMapFeatureState

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
    data object LocationPermissionGranted : NearbyVehicleMapScreenEvent

    data object LocationPermissionDenied : NearbyVehicleMapScreenEvent

    data object LocationTemporarilyUnavailable : NearbyVehicleMapScreenEvent

    data class VisibleRefreshDue(
        val nowMillis: Long,
    ) : NearbyVehicleMapScreenEvent

    data class ManualRefreshRequested(
        val nowMillis: Long,
    ) : NearbyVehicleMapScreenEvent
}
