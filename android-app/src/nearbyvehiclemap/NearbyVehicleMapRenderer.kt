package studio.mekate.mobi.nearbyvehiclemap

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.PropertyFactory.circleColor
import org.maplibre.android.style.layers.PropertyFactory.circleRadius
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeColor
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeWidth
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.Point

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
                map.setStyle(styleUrl) { style ->
                    map.render(
                        style = style,
                        scene = scene,
                    )
                }
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

private fun MapLibreMap.render(
    style: Style,
    scene: NearbyVehicleMapScenePresentation?,
) {
    val camera = scene?.camera ?: DEFAULT_CAMERA
    cameraPosition =
        CameraPosition
            .Builder()
            .target(camera.target.toLatLng())
            .zoom(camera.zoom)
            .build()

    style.ensureNearbyVehicleMapLayers()
    style.setNearbyVehicleMapSource(
        sourceId = RIDER_SOURCE_ID,
        features =
            if (scene == null) {
                emptyList()
            } else {
                listOf(scene.riderMarker.toFeature())
            },
    )
    style.setNearbyVehicleMapSource(
        sourceId = VEHICLE_SOURCE_ID,
        features = scene?.vehicleMarkers?.map { it.toFeature() }.orEmpty(),
    )
}

private fun Style.ensureNearbyVehicleMapLayers() {
    if (getSource(RIDER_SOURCE_ID) == null) {
        addSource(GeoJsonSource(RIDER_SOURCE_ID, emptyFeatureCollection()))
    }
    if (getSource(VEHICLE_SOURCE_ID) == null) {
        addSource(GeoJsonSource(VEHICLE_SOURCE_ID, emptyFeatureCollection()))
    }
    if (getLayer(VEHICLE_LAYER_ID) == null) {
        addLayer(
            CircleLayer(VEHICLE_LAYER_ID, VEHICLE_SOURCE_ID).withProperties(
                circleRadius(5f),
                circleColor("#2563EB"),
                circleStrokeColor("#FFFFFF"),
                circleStrokeWidth(1.5f),
            ),
        )
    }
    if (getLayer(RIDER_LAYER_ID) == null) {
        addLayer(
            CircleLayer(RIDER_LAYER_ID, RIDER_SOURCE_ID).withProperties(
                circleRadius(7f),
                circleColor("#DC2626"),
                circleStrokeColor("#FFFFFF"),
                circleStrokeWidth(2f),
            ),
        )
    }
}

private fun Style.setNearbyVehicleMapSource(
    sourceId: String,
    features: List<Feature>,
) {
    getSourceAs<GeoJsonSource>(sourceId)
        ?.setGeoJson(FeatureCollection.fromFeatures(features))
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

private fun NearbyVehicleMapRiderMarkerPresentation.toFeature(): Feature = coordinate.toFeature()

private fun NearbyVehicleMapVehicleMarkerPresentation.toFeature(): Feature = coordinate.toFeature()

private fun NearbyVehicleMapCoordinatePresentation.toFeature(): Feature =
    Feature.fromGeometry(
        Point.fromLngLat(
            longitude,
            latitude,
        ),
    )

private fun emptyFeatureCollection(): FeatureCollection = FeatureCollection.fromFeatures(emptyList())

private const val RIDER_SOURCE_ID = "mobi-rider-source"
private const val VEHICLE_SOURCE_ID = "mobi-vehicle-source"
private const val RIDER_LAYER_ID = "mobi-rider-layer"
private const val VEHICLE_LAYER_ID = "mobi-vehicle-layer"
