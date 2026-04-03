package studio.mekate.b3.home

import android.os.Parcel
import android.os.Parcelable
import com.slack.circuit.runtime.CircuitUiState
import com.slack.circuit.runtime.screen.Screen
import studio.mekate.b3.feature.home.HomeFeatureState

data object HomeScreen : Screen {
    override fun describeContents(): Int = 0

    override fun writeToParcel(parcel: Parcel, flags: Int) = Unit

    @JvmField
    val CREATOR: Parcelable.Creator<HomeScreen> = object : Parcelable.Creator<HomeScreen> {
        override fun createFromParcel(parcel: Parcel): HomeScreen = HomeScreen

        override fun newArray(size: Int): Array<HomeScreen?> = arrayOfNulls(size)
    }
}

data class HomeScreenState(
    val featureState: HomeFeatureState,
    val eventSink: (HomeScreenEvent) -> Unit,
) : CircuitUiState

sealed interface HomeScreenEvent {
    data object RefreshClicked : HomeScreenEvent
}
