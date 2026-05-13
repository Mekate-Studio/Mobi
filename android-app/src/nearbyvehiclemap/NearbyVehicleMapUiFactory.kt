package studio.mekate.mobi.nearbyvehiclemap

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.slack.circuit.runtime.CircuitContext
import com.slack.circuit.runtime.screen.Screen
import com.slack.circuit.runtime.ui.Ui
import com.slack.circuit.runtime.ui.ui
import dev.zacsweers.metro.Inject

@Inject
class NearbyVehicleMapUiFactory : Ui.Factory {
    override fun create(
        screen: Screen,
        context: CircuitContext,
    ): Ui<*>? =
        when (screen) {
            NearbyVehicleMapScreen -> {
                ui<NearbyVehicleMapScreenState> { state, modifier ->
                    NearbyVehicleMapContent(
                        state = state,
                        modifier = modifier,
                    )
                }
            }

            else -> {
                null
            }
        }
}

@Composable
private fun NearbyVehicleMapContent(
    state: NearbyVehicleMapScreenState,
    modifier: Modifier = Modifier,
) {
    val presentation = state.featureState.toNearbyVehicleMapPresentation()
    val permissionLauncher =
        rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
            if (isGranted) {
                state.eventSink(NearbyVehicleMapScreenEvent.LocationPermissionGranted)
            } else {
                state.eventSink(NearbyVehicleMapScreenEvent.LocationPermissionDenied)
            }
        }

    MaterialTheme {
        Column(
            modifier =
                modifier
                    .fillMaxSize()
                    .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                text = presentation.title,
                style = MaterialTheme.typography.headlineMedium,
            )
            Text(
                text = presentation.message,
                style = MaterialTheme.typography.bodyLarge,
            )
            NearbyVehicleCoordinateMap(
                mapContent = presentation.mapContent,
                overlay = presentation.overlay,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .weight(1f),
            )
            NearbyVehicleMapActions(
                presentation = presentation,
                onPermissionRequested = {
                    permissionLauncher.launch(android.Manifest.permission.ACCESS_FINE_LOCATION)
                },
                onRefreshRequested = {
                    state.eventSink(
                        NearbyVehicleMapScreenEvent.ManualRefreshRequested(
                            nowMillis = System.currentTimeMillis(),
                        ),
                    )
                },
                onLocationLossRequested = {
                    state.eventSink(NearbyVehicleMapScreenEvent.LocationTemporarilyUnavailable)
                },
            )
        }
    }
}

@Composable
private fun NearbyVehicleMapActions(
    presentation: NearbyVehicleMapPresentation,
    onPermissionRequested: () -> Unit,
    onRefreshRequested: () -> Unit,
    onLocationLossRequested: () -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Button(onClick = onPermissionRequested) {
            Text("Use rider location")
        }
        OutlinedButton(
            enabled = presentation.canRequestRefresh,
            onClick = onRefreshRequested,
        ) {
            Text(presentation.primaryActionLabel)
        }
    }
    OutlinedButton(onClick = onLocationLossRequested) {
        Text("Simulate temporary location loss")
    }
}

@Composable
private fun NearbyVehicleCoordinateMap(
    mapContent: NearbyVehicleMapContentPresentation,
    overlay: NearbyVehicleMapOverlayPresentation,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(28.dp),
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .background(Color(0xFFEAF3ED)),
        ) {
            CoordinateMapCanvas(
                mapContent = mapContent,
            )
            CoordinateMapHeader()
            CoordinateMapOverlay(overlay = overlay)
            WaitingForRiderLocationLabel(mapContent = mapContent)
            CoordinateMapLegend()
        }
    }
}

@Composable
private fun CoordinateMapCanvas(mapContent: NearbyVehicleMapContentPresentation) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        drawCoordinateGrid()
        if (mapContent is NearbyVehicleMapContentPresentation.RiderCentered) {
            val center = Offset(x = size.width / 2f, y = size.height / 2f)
            drawRiderMarker(center = center)
            mapContent.vehicles.forEach { vehicle ->
                drawVehicleMarker(
                    vehicle = vehicle,
                    riderLocation = mapContent.riderLocation,
                    center = center,
                )
            }
        }
    }
}

@Composable
private fun CoordinateMapHeader() {
    Column(
        modifier =
            Modifier
                .padding(18.dp),
    ) {
        Text(
            text = "Rider-centered coordinate map",
            style = MaterialTheme.typography.titleMedium,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "No SDK key required; markers are projected from shared lat/lon state.",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

@Composable
private fun BoxScope.CoordinateMapOverlay(overlay: NearbyVehicleMapOverlayPresentation) {
    when (overlay) {
        NearbyVehicleMapOverlayPresentation.None -> {
            Unit
        }

        is NearbyVehicleMapOverlayPresentation.Banner -> {
            CoordinateMapOverlayCard(
                headline = overlay.headline,
                message = overlay.message,
                blocksMap = false,
            )
        }

        is NearbyVehicleMapOverlayPresentation.Blocking -> {
            CoordinateMapOverlayCard(
                headline = overlay.headline,
                message = overlay.message,
                blocksMap = true,
            )
        }
    }
}

@Composable
private fun BoxScope.CoordinateMapOverlayCard(
    headline: String,
    message: String,
    blocksMap: Boolean,
) {
    Column(
        modifier =
            Modifier
                .align(if (blocksMap) Alignment.Center else Alignment.BottomCenter)
                .padding(18.dp)
                .background(
                    color = if (blocksMap) Color(0xEE2E241C) else Color(0xEEFFF8E8),
                    shape = RoundedCornerShape(18.dp),
                ).padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = headline,
            color = if (blocksMap) Color.White else Color(0xFF5F3B00),
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            text = message,
            color = if (blocksMap) Color.White else Color(0xFF5F3B00),
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

@Composable
private fun BoxScope.WaitingForRiderLocationLabel(mapContent: NearbyVehicleMapContentPresentation) {
    if (mapContent is NearbyVehicleMapContentPresentation.WaitingForRider) {
        Text(
            text = "Waiting for rider position",
            modifier =
                Modifier
                    .align(Alignment.Center)
                    .background(Color(0xDDFFFFFF), RoundedCornerShape(20.dp))
                    .padding(18.dp),
            style = MaterialTheme.typography.titleMedium,
        )
    }
}

@Composable
private fun BoxScope.CoordinateMapLegend() {
    Row(
        modifier =
            Modifier
                .align(Alignment.BottomStart)
                .padding(18.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LegendDot(color = Color(0xFF0E5F41))
        Text("Rider")
        LegendDot(color = Color(0xFFD97A35))
        Text("Vehicle")
    }
}

@Composable
private fun LegendDot(color: Color) {
    Box(
        modifier =
            Modifier
                .size(12.dp)
                .background(color, RoundedCornerShape(6.dp)),
    )
}
