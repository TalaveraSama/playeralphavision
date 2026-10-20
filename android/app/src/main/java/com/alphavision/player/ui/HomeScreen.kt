package com.alphavision.player.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.alphavision.core.LiveStream
import com.alphavision.core.Series
import com.alphavision.core.VodStream

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    state: UiState,
    onTab: (Tab) -> Unit,
    onQuery: (String) -> Unit,
    onLiveCategory: (String?) -> Unit,
    onVodCategory: (String?) -> Unit,
    onSeriesCategory: (String?) -> Unit,
    onPlayChannel: (LiveStream) -> Unit,
    onPlayMovie: (VodStream) -> Unit,
    onOpenSeries: (Series) -> Unit,
    onRetry: () -> Unit,
    onLogout: () -> Unit,
) {
    val user = state.user
    val statusLine = user?.let {
        val days = it.daysLeft(System.currentTimeMillis() / 1000)
        buildString {
            append(it.subscription.name.lowercase().replaceFirstChar { c -> c.uppercase() })
            if (days != null && days > 0) append(" · $days días")
            if (it.maxConnections > 0) append(" · ${it.activeConnections}/${it.maxConnections} conexiones")
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
                title = {
                    Column {
                        Text(
                            text = "ALPHA VISION",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        if (statusLine != null) {
                            Text(
                                text = statusLine,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                },
                actions = {
                    IconButton(onClick = onLogout) {
                        Icon(Icons.Filled.ExitToApp, contentDescription = "Salir")
                    }
                },
            )
        },
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                NavigationBarItem(
                    selected = state.tab == Tab.LIVE,
                    onClick = { onTab(Tab.LIVE) },
                    icon = { Icon(Icons.Filled.Tv, contentDescription = null) },
                    label = { Text("TV") },
                )
                NavigationBarItem(
                    selected = state.tab == Tab.MOVIES,
                    onClick = { onTab(Tab.MOVIES) },
                    icon = { Icon(Icons.Filled.Movie, contentDescription = null) },
                    label = { Text("Películas") },
                )
                NavigationBarItem(
                    selected = state.tab == Tab.SERIES,
                    onClick = { onTab(Tab.SERIES) },
                    icon = { Icon(Icons.Filled.Home, contentDescription = null) },
                    label = { Text("Series") },
                )
            }
        },
    ) { innerPadding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            OutlinedTextField(
                value = state.query,
                onValueChange = onQuery,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                placeholder = { Text("Buscar…") },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                singleLine = true,
            )

            when (state.tab) {
                Tab.LIVE -> LiveContent(
                    channels = state.live,
                    categories = state.liveCategories,
                    selectedCategory = state.selectedLiveCategory,
                    query = state.query,
                    loading = state.loading,
                    error = state.error,
                    onSelectCategory = onLiveCategory,
                    onPlay = onPlayChannel,
                    onRetry = onRetry,
                )
                Tab.MOVIES -> VodContent(
                    movies = state.vod,
                    categories = state.vodCategories,
                    selectedCategory = state.selectedVodCategory,
                    query = state.query,
                    loading = state.loading,
                    error = state.error,
                    onSelectCategory = onVodCategory,
                    onPlay = onPlayMovie,
                    onRetry = onRetry,
                )
                Tab.SERIES -> SeriesContent(
                    series = state.series,
                    categories = state.seriesCategories,
                    selectedCategory = state.selectedSeriesCategory,
                    query = state.query,
                    loading = state.loading,
                    error = state.error,
                    onSelectCategory = onSeriesCategory,
                    onOpen = onOpenSeries,
                    onRetry = onRetry,
                )
            }
        }
    }
}
