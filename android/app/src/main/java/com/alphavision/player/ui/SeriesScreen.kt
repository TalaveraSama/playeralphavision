package com.alphavision.player.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.alphavision.core.Category
import com.alphavision.core.Series

internal fun filterSeries(
    series: List<Series>,
    categoryId: String?,
    query: String,
): List<Series> {
    val q = query.trim().lowercase()
    return series.filter { item ->
        (categoryId == null || item.categoryId == categoryId) &&
            (q.isEmpty() || item.name.lowercase().contains(q))
    }
}

@Composable
fun SeriesContent(
    series: List<Series>,
    categories: List<Category>,
    selectedCategory: String?,
    query: String,
    loading: Boolean,
    error: String?,
    onSelectCategory: (String?) -> Unit,
    onOpen: (Series) -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val visible = remember(series, selectedCategory, query) {
        filterSeries(series, selectedCategory, query)
    }

    Column(modifier.fillMaxSize()) {
        if (categories.isNotEmpty()) {
            CategoryRow(categories, selectedCategory, onSelectCategory)
        }
        when {
            loading && series.isEmpty() -> LoadingBox("Cargando series…")
            error != null && series.isEmpty() -> ErrorBox(error, onRetry)
            visible.isEmpty() -> EmptyBox("No hay series que coincidan.")
            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(visible, key = { it.seriesId }) { item ->
                    PosterCard(
                        title = item.name,
                        imageUrl = item.cover,
                        subtitle = item.rating?.let { "★ $it" },
                        onClick = { onOpen(item) },
                    )
                }
            }
        }
    }
}
