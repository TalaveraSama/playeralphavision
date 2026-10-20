package com.alphavision.player.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.alphavision.core.Category
import com.alphavision.core.LiveStream

/** Filtra por categoría y por texto (nombre del canal). */
internal fun filterLive(
    streams: List<LiveStream>,
    categoryId: String?,
    query: String,
): List<LiveStream> {
    val q = query.trim().lowercase()
    return streams.filter { stream ->
        (categoryId == null || stream.categoryId == categoryId) &&
            (q.isEmpty() || stream.name.lowercase().contains(q))
    }
}

@Composable
fun LiveContent(
    channels: List<LiveStream>,
    categories: List<Category>,
    selectedCategory: String?,
    query: String,
    loading: Boolean,
    error: String?,
    onSelectCategory: (String?) -> Unit,
    onPlay: (LiveStream) -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val visible = remember(channels, selectedCategory, query) {
        filterLive(channels, selectedCategory, query)
    }
    val categoryNames = remember(categories) { categories.associate { it.id to it.name } }

    Column(modifier.fillMaxSize()) {
        if (categories.isNotEmpty()) {
            CategoryRow(
                categories = categories,
                selectedId = selectedCategory,
                onSelect = onSelectCategory,
            )
        }
        when {
            loading && channels.isEmpty() -> LoadingBox("Cargando canales…")
            error != null && channels.isEmpty() -> ErrorBox(error, onRetry)
            visible.isEmpty() -> EmptyBox("No hay canales que coincidan.")
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(visible, key = { it.streamId }) { channel ->
                    ChannelRow(
                        name = channel.name,
                        iconUrl = channel.streamIcon,
                        subtitle = categoryNames[channel.categoryId]
                            ?: if (channel.hasArchive) "Con archivo (7 días)" else null,
                        onClick = { onPlay(channel) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}
