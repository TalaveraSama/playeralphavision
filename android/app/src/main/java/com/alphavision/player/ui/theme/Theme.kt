package com.alphavision.player.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val AlphaGreen = Color(0xFF00E5A0)
val AlphaDark = Color(0xFF0B0F14)
val AlphaSurface = Color(0xFF151B23)
val AlphaSurfaceHigh = Color(0xFF1E2732)
val AlphaMuted = Color(0xFF9AA7B4)

private val DarkColors = darkColorScheme(
    primary = AlphaGreen,
    onPrimary = Color(0xFF00281C),
    primaryContainer = Color(0xFF00422F),
    onPrimaryContainer = AlphaGreen,
    secondary = Color(0xFF7FD1FF),
    onSecondary = Color(0xFF00344A),
    background = AlphaDark,
    onBackground = Color(0xFFE7EDF3),
    surface = AlphaSurface,
    onSurface = Color(0xFFE7EDF3),
    surfaceVariant = AlphaSurfaceHigh,
    onSurfaceVariant = AlphaMuted,
    error = Color(0xFFFF6B6B),
)

private val LightColors = lightColorScheme(
    primary = Color(0xFF007A57),
    secondary = Color(0xFF00658C),
)

@Composable
fun AlphaVisionTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
