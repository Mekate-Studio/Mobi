package studio.mekate.mobi.nearbyvehiclemap

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import org.maplibre.android.MapLibre
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView

@Composable
fun NearbyVehicleMapRenderer(
    scene: NearbyVehicleMapScenePresentation?,
    modifier: Modifier = Modifier,
    styleUrl: String = NearbyVehicleMapBasemapConfig.DEFAULT_STYLE_URL,
) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val mapView =
        remember {
            createNearbyVehicleMapView(
                context = context,
                styleUrl = styleUrl,
            )
        }

    DisposableEffect(lifecycle, mapView) {
        val observer =
            LifecycleEventObserver { _, event ->
                when (event) {
                    Lifecycle.Event.ON_START -> mapView.onStart()

                    Lifecycle.Event.ON_RESUME -> mapView.onResume()

                    Lifecycle.Event.ON_PAUSE -> mapView.onPause()

                    Lifecycle.Event.ON_STOP -> mapView.onStop()

                    Lifecycle.Event.ON_DESTROY -> mapView.onDestroy()

                    Lifecycle.Event.ON_CREATE,
                    Lifecycle.Event.ON_ANY,
                    -> Unit
                }
            }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            mapView.onDestroy()
        }
    }

    AndroidView(
        factory = { mapView },
        modifier = modifier,
        update = { view ->
            view.getMapAsync { map ->
                map.setStyle(styleUrl)
                map.render(scene = scene)
            }
        },
    )
}

private fun createNearbyVehicleMapView(
    context: Context,
    styleUrl: String,
): MapView {
    MapLibre.getInstance(context.applicationContext)
    return MapView(context).apply {
        onCreate(null)
        onStart()
        onResume()
        getMapAsync { map ->
            map.setStyle(styleUrl)
        }
    }
}

private fun MapLibreMap.render(scene: NearbyVehicleMapScenePresentation?) {
    val camera = scene?.camera ?: DEFAULT_CAMERA
    cameraPosition =
        CameraPosition
            .Builder()
            .target(camera.target.toLatLng())
            .zoom(camera.zoom)
            .build()

    clear()
    if (scene == null) return

    addMarker(
        MarkerOptions()
            .position(scene.riderMarker.coordinate.toLatLng())
            .title("Rider"),
    )
    scene.vehicleMarkers.forEach { marker ->
        addMarker(
            MarkerOptions()
                .position(marker.coordinate.toLatLng())
                .title(marker.id),
        )
    }
}

private fun NearbyVehicleMapCoordinatePresentation.toLatLng(): LatLng =
    LatLng(
        latitude,
        longitude,
    )

private val DEFAULT_CAMERA =
    NearbyVehicleMapCameraPresentation(
        target =
            NearbyVehicleMapCoordinatePresentation(
                latitude = 55.6761,
                longitude = 12.5683,
            ),
        zoom = 12.0,
    )
