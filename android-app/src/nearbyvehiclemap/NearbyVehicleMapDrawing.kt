package studio.mekate.mobi.nearbyvehiclemap

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import studio.mekate.mobi.core.NearbyVehicle
import studio.mekate.mobi.core.RiderLocation
import studio.mekate.mobi.core.VehicleLocation

fun DrawScope.drawCoordinateGrid() {
    val gridColor = Color(0x55395B45)
    repeat(6) { index ->
        val fraction = (index + 1) / 7f
        drawLine(
            color = gridColor,
            start = Offset(x = size.width * fraction, y = 0f),
            end = Offset(x = size.width * fraction, y = size.height),
            strokeWidth = 1.dp.toPx(),
        )
        drawLine(
            color = gridColor,
            start = Offset(x = 0f, y = size.height * fraction),
            end = Offset(x = size.width, y = size.height * fraction),
            strokeWidth = 1.dp.toPx(),
        )
    }
}

fun DrawScope.drawRiderMarker(center: Offset) {
    drawCircle(
        color = Color(0xFF0E5F41),
        radius = 16.dp.toPx(),
        center = center,
    )
    drawCircle(
        color = Color.White,
        radius = 7.dp.toPx(),
        center = center,
    )
}

fun DrawScope.drawVehicleMarker(
    vehicle: NearbyVehicle,
    riderLocation: RiderLocation,
    center: Offset,
) {
    val offset = vehicle.location.toOffsetFrom(riderLocation)
    val markerCenter =
        Offset(
            x = center.x + (offset.x * size.minDimension * MAP_SCALE),
            y = center.y - (offset.y * size.minDimension * MAP_SCALE),
        )
    drawCircle(
        color = Color(0xFFD97A35),
        radius = 13.dp.toPx(),
        center = markerCenter,
    )
    drawCircle(
        color = Color(0xFF6A2D0F),
        radius = 13.dp.toPx(),
        center = markerCenter,
        style = Stroke(width = 2.dp.toPx()),
    )
}

private data class MapOffset(
    val x: Float,
    val y: Float,
)

private fun VehicleLocation.toOffsetFrom(riderLocation: RiderLocation): MapOffset =
    MapOffset(
        x = ((longitude - riderLocation.longitude) * LONGITUDE_SCALE).toFloat(),
        y = ((latitude - riderLocation.latitude) * LATITUDE_SCALE).toFloat(),
    )

private const val LATITUDE_SCALE = 1_000.0
private const val LONGITUDE_SCALE = 1_800.0
private const val MAP_SCALE = 0.42f
