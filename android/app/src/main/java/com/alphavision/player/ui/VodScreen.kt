package com.alphavision.player.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.alphavision.core.Category
import com.alphavision.core.VodStream

internal fun filterVod(
    movies: List<VodStream>,
    categoryId: String?,
    query: String,
): List<VodStream> {
    val q = query.trim().lowercase()
    return movies.filter { movie ->
        (categoryId == null || movie.categoryId == categoryId) &&
            (q.isEmpty() || movie.name.lowercase().contains(q))
    }
}

@Composable
fun VodContent(
    movies: List<VodStream>,
    categories: List<Category>,
    selectedCategory: String?,
    query: String,
    loading: Boolean,
    error: String?,
    onSelectCategory: (String?) -> Unit,
    onPlay: (VodStream) -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val visible = remember(movies, selectedCategory, query) {
        filterVod(movies, selectedCategory, query)
    }

    Column(modifier.fillMaxSize()) {
        if (categories.isNotEmpty()) {
            CategoryRow(categories, selectedCategory, onSelectCategory)
        }
        when {
            loading && movies.isEmpty() -> LoadingBox("Cargando películas…")
            error != null && movies.isEmpty() -> ErrorBox(error, onRetry)
            visible.isEmpty() -> EmptyBox("No hay películas que coincidan.")
            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(visible, key = { it.streamId }) { movie ->
                    PosterCard(
                        title = movie.name,
                        imageUrl = movie.streamIcon,
                        subtitle = movie.rating?.let { "★ $it" },
                        onClick = { onPlay(movie) },
                    )
                }
            }
        }
    }
}
