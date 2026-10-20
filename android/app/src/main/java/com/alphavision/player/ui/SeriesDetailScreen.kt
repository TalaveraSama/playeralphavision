package com.alphavision.player.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.alphavision.core.Episode
import com.alphavision.player.ui.theme.AlphaSurfaceHigh

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SeriesDetailScreen(
    state: UiState,
    title: String,
    onBack: () -> Unit,
    onPlayEpisode: (Episode, String) -> Unit,
) {
    val detail = state.seriesDetail
    var selectedSeason by remember(detail) { mutableStateOf(detail?.seasons?.keys?.firstOrNull()) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Volver")
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.seriesDetailLoading -> Box(
                Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            ) { LoadingBox("Cargando episodios…") }

            detail == null -> Box(
                Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            ) { EmptyBox("No se pudo cargar la serie.") }

            else -> LazyColumn(
                Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                        Box(
                            Modifier
                                .size(width = 104.dp, height = 156.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(AlphaSurfaceHigh),
                        ) {
                            val cover = detail.info?.cover
                            if (!cover.isNullOrBlank()) {
                                AsyncImage(
                                    model = cover,
                                    contentDescription = title,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize(),
                                )
                            }
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            val plot = detail.info?.plot
                            if (!plot.isNullOrBlank()) {
                                Text(
                                    text = plot,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 6,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                            val genre = detail.info?.genre
                            if (!genre.isNullOrBlank()) {
                                Spacer(Modifier.height(6.dp))
                                Text(
                                    text = genre,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                            val cast = detail.info?.cast
                            if (!cast.isNullOrBlank()) {
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    text = cast,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                        }
                    }
                }

                item {
                    if (detail.seasons.size > 1) {
                        LazyRow(
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            items(detail.seasons.keys.toList()) { season ->
                                FilterChip(
                                    selected = selectedSeason == season,
                                    onClick = { selectedSeason = season },
                                    label = { Text("Temporada $season") },
                                )
                            }
                        }
                    }
                }

                val episodes = (selectedSeason?.let { detail.seasons[it] } ?: emptyList())
                items(episodes, key = { it.id }) { episode ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(AlphaSurfaceHigh)
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                text = "${episode.episodeNum}. ${episode.title}",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                            )
                            val plot = episode.plot
                            if (!plot.isNullOrBlank()) {
                                Text(
                                    text = plot,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                        }
                        IconButton(onClick = { onPlayEpisode(episode, title) }) {
                            Icon(
                                Icons.Filled.PlayArrow,
                                contentDescription = "Reproducir",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(30.dp),
                            )
                        }
                    }
                }

                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}
