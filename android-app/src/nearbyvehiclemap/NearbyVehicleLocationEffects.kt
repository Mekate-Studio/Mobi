package studio.mekate.mobi.nearbyvehiclemap

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.flow.first

@Composable
internal fun NearbyVehicleLocationEffects(state: NearbyVehicleMapScreenState) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val permissionLauncher =
        rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            // Re-read Android state instead of trusting a possibly obsolete grants payload.
            if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                state.eventSink(AndroidNearbyVehicleLocationResolver.resolveCurrentLocation(context).toScreenEvent())
            }
        }

    LifecycleEventEffect(Lifecycle.Event.ON_START, lifecycleOwner) {
        state.eventSink(AndroidNearbyVehicleLocationResolver.resolveCurrentLocation(context).toScreenEvent())
    }

    LaunchedEffect(context, lifecycleOwner) {
        lifecycleOwner.lifecycle.currentStateFlow.first { it.isAtLeast(Lifecycle.State.STARTED) }
        if (AndroidNearbyVehicleLocationResolver.resolveCurrentLocation(context) ==
            AndroidNearbyVehicleLocationResult.PermissionRequired
        ) {
            permissionLauncher.launch(AndroidNearbyVehicleLocationResolver.locationPermissions)
        }
    }
}
