package studio.mekate.mobi.ui.home

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
import studio.mekate.mobi.feature.home.CounterLoadable
import studio.mekate.mobi.feature.home.CounterLoadFailureReason
import studio.mekate.mobi.feature.home.HomeFeatureEvent
import studio.mekate.mobi.feature.home.HomeFeatureState
import studio.mekate.mobi.feature.home.HomeFeatureService
import studio.mekate.mobi.feature.home.currentValueForRefresh

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
    val contentCopy = state.toContentCopy()

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
                        text = contentCopy.title,
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    Text(
                        text = contentCopy.message,
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text(
                        text = contentCopy.supportingText,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        text = contentCopy.counterValueText,
                        style = MaterialTheme.typography.labelLarge,
                    )
                    Button(
                        enabled = !contentCopy.isLoading,
                        onClick = { onEvent(HomeFeatureEvent.RefreshClicked) },
                    ) {
                        Text(if (contentCopy.isLoading) "Loading…" else contentCopy.primaryActionLabel)
                    }
                }
            }
        }
    }
}

private data class HomeContentCopy(
    val title: String,
    val message: String,
    val supportingText: String,
    val counterValueText: String,
    val primaryActionLabel: String,
    val isLoading: Boolean,
)

private fun HomeFeatureState.toContentCopy(): HomeContentCopy {
    val loadable = counterLoadable

    return HomeContentCopy(
        title = "Shared feature, platform rendering",
        message = "Shared business logic feeding a platform-specific screen.",
        supportingText = loadable.toSupportingText(),
        counterValueText = loadable.toCounterValueText(),
        primaryActionLabel = "Load next counter value",
        isLoading = loadable is CounterLoadable.Loading,
    )
}

private fun CounterLoadable.toSupportingText(): String {
    return when (this) {
        CounterLoadable.Initial -> {
            "Tap the action to load the next fibonacci counter value from the fake repository."
        }

        is CounterLoadable.Loading -> {
            "Loading the next fibonacci counter value from the fake repository."
        }

        is CounterLoadable.Loaded -> {
            "The fake repository returned fibonacci counter value $value."
        }

        is CounterLoadable.Error -> {
            buildString {
                append(reason.headlineText())
                if (previousValue != null) {
                    append(" Showing last known counter value $previousValue.")
                } else {
                    append(" No fibonacci counter value was loaded yet.")
                }
            }
        }
    }
}

private fun CounterLoadFailureReason.headlineText(): String {
    return when (this) {
        CounterLoadFailureReason.RepositoryUnavailable -> {
            "The fake repository failed to load the next fibonacci counter value."
        }

        CounterLoadFailureReason.Unexpected -> {
            "Something went wrong while loading the next fibonacci counter value."
        }
    }
}

private fun CounterLoadable.toCounterValueText(): String {
    return when (this) {
        CounterLoadable.Initial -> "Counter value: Not loaded yet"
        is CounterLoadable.Loading -> {
            previousValue?.let { "Counter value: $it" } ?: "Counter value: Loading first result…"
        }

        is CounterLoadable.Loaded -> "Counter value: $value"
        is CounterLoadable.Error -> {
            previousValue?.let { "Counter value: $it" } ?: "Counter value: No value available"
        }
    }
}
