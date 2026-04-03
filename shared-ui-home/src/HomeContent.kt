package studio.mekate.b3.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import studio.mekate.b3.feature.home.HomeFeatureEvent
import studio.mekate.b3.feature.home.HomeFeatureState
import studio.mekate.b3.feature.home.HomeFeatureStateFactory

@Composable
fun SharedHomeScreen(
    stateFactory: HomeFeatureStateFactory,
    modifier: Modifier = Modifier,
) {
    var refreshCount by rememberSaveable { mutableIntStateOf(0) }
    val state = remember(refreshCount, stateFactory) {
        stateFactory.create(refreshCount = refreshCount)
    }

    HomeContent(
        state = state,
        modifier = modifier,
        onEvent = { event ->
            refreshCount = stateFactory.reduce(refreshCount = refreshCount, event = event)
        },
    )
}

@Composable
fun HomeContent(
    state: HomeFeatureState,
    onEvent: (HomeFeatureEvent) -> Unit,
    modifier: Modifier = Modifier,
) {
    MaterialTheme {
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = state.title,
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    Text(
                        text = state.message,
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text(
                        text = state.supportingText,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        text = "Refresh count: ${state.refreshCount}",
                        style = MaterialTheme.typography.labelLarge,
                    )
                    Button(
                        onClick = { onEvent(HomeFeatureEvent.RefreshClicked) },
                    ) {
                        Text(state.primaryActionLabel)
                    }
                }
            }
        }
    }
}
