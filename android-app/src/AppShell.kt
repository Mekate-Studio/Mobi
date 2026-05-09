package studio.mekate.mobi

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.slack.circuit.foundation.CircuitCompositionLocals
import com.slack.circuit.foundation.CircuitContent
import studio.mekate.mobi.di.SharedDependencies
import studio.mekate.mobi.home.HomeScreen
import studio.mekate.mobi.nearbyvehiclemap.NearbyVehicleMapScreen
import studio.mekate.mobi.ui.home.SharedHomeScreen

@Composable
fun AppShell() {
    var destination by rememberSaveable { mutableIntStateOf(AppDestination.NativeHome.ordinal) }
    val selectedDestination = AppDestination.entries[destination]
    val sharedGraph = remember { SharedDependencies.createDefaultGraph() }
    val appGraph = remember(sharedGraph) { AndroidDependencies.createGraph(sharedGraph) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                AppDestination.entries.forEach { item ->
                    NavigationBarItem(
                        selected = selectedDestination == item,
                        onClick = { destination = item.ordinal },
                        icon = { Text(item.shortLabel) },
                        label = { Text(item.label) },
                    )
                }
            }
        },
    ) { paddingValues ->
        when (selectedDestination) {
            AppDestination.NativeHome -> {
                CircuitCompositionLocals(appGraph.circuit) {
                    CircuitContent(
                        HomeScreen,
                        modifier = Modifier.padding(paddingValues),
                    )
                }
            }

            AppDestination.NearbyVehicleMap -> {
                CircuitCompositionLocals(appGraph.circuit) {
                    CircuitContent(
                        NearbyVehicleMapScreen,
                        modifier = Modifier.padding(paddingValues),
                    )
                }
            }

            AppDestination.SharedComposeDemo -> {
                SharedHomeScreen(
                    service = sharedGraph.homeFeatureService,
                    modifier = Modifier.padding(paddingValues),
                )
            }
        }
    }
}

private enum class AppDestination(
    val label: String,
    val shortLabel: String,
) {
    NativeHome(label = "Native Home", shortLabel = "N"),
    NearbyVehicleMap(label = "Nearby Map", shortLabel = "M"),
    SharedComposeDemo(label = "Shared UI", shortLabel = "S"),
}
