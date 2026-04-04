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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import studio.mekate.b3.feature.home.CounterLoadable
import studio.mekate.b3.feature.home.HomeFeatureEvent
import studio.mekate.b3.feature.home.HomeFeatureState
import studio.mekate.b3.feature.home.HomeFeatureService
import studio.mekate.b3.feature.home.currentValueForRefresh

@Composable
fun SharedHomeScreen(
    service: HomeFeatureService,
    modifier: Modifier = Modifier,
) {
    var state by remember(service) { mutableStateOf(service.initialState()) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(service) {
        state = service.initialState()
    }

    HomeContent(
        state = state,
        modifier = modifier,
        onEvent = { event ->
            if (state.counterLoadable !is CounterLoadable.Loading) {
                scope.launch {
                    val currentCounterValue = state.counterLoadable.currentValueForRefresh()
                    state = service.loadingState(counterValue = currentCounterValue)
                    state = service.refresh(counterValue = currentCounterValue)
                }
            }
        },
    )
}

@Composable
fun HomeContent(
    state: HomeFeatureState,
    onEvent: (HomeFeatureEvent) -> Unit,
    modifier: Modifier = Modifier,
) {
    val counterValueText = when (val counterLoadable = state.counterLoadable) {
        CounterLoadable.Initial -> "Counter value: Not loaded yet"
        is CounterLoadable.Loading -> {
            counterLoadable.previousValue?.let { "Counter value: $it" } ?: "Counter value: Loading first result…"
        }

        is CounterLoadable.Loaded -> "Counter value: ${counterLoadable.value}"
        is CounterLoadable.Error -> {
            counterLoadable.previousValue?.let { "Counter value: $it" } ?: "Counter value: No value available"
        }
    }
    val isLoading = state.counterLoadable is CounterLoadable.Loading

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
                        text = counterValueText,
                        style = MaterialTheme.typography.labelLarge,
                    )
                    Button(
                        enabled = !isLoading,
                        onClick = { onEvent(HomeFeatureEvent.RefreshClicked) },
                    ) {
                        Text(if (isLoading) "Loading…" else state.primaryActionLabel)
                    }
                }
            }
        }
    }
}
