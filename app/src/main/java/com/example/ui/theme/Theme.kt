package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = ShopGeniePrimary,
    onPrimary = ShopGenieOnPrimary,
    primaryContainer = ShopGeniePrimaryContainer,
    onPrimaryContainer = ShopGenieOnPrimaryContainer,
    secondary = ShopGenieSecondary,
    onSecondary = ShopGenieOnSecondary,
    secondaryContainer = ShopGenieSecondaryContainer,
    onSecondaryContainer = ShopGenieOnSecondaryContainer,
    tertiary = ShopGenieTertiary,
    onTertiary = ShopGenieOnTertiary,
    tertiaryContainer = ShopGenieTertiaryContainer,
    onTertiaryContainer = ShopGenieOnTertiaryContainer,
    background = ShopGenieBackground,
    onBackground = ShopGenieOnBackground,
    surface = ShopGenieSurface,
    onSurface = ShopGenieOnSurface,
    surfaceVariant = ShopGenieSurfaceVariant,
    onSurfaceVariant = ShopGenieOnSurfaceVariant,
    error = ShopGenieError,
    onError = Color.White
)

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFA5C8FF),
    onPrimary = Color(0xFF00315E),
    primaryContainer = Color(0xFF004785),
    onPrimaryContainer = Color(0xFFD4E3FF),
    secondary = Color(0xFFFFB951),
    onSecondary = Color(0xFF452B00),
    secondaryContainer = Color(0xFF633F00),
    onSecondaryContainer = Color(0xFFFFDDB3),
    tertiary = Color(0xFF53DBC9),
    onTertiary = Color(0xFF003731),
    background = Color(0xFF0F172A),
    onBackground = Color(0xFFF1F5F9),
    surface = Color(0xFF1E293B),
    onSurface = Color(0xFFF1F5F9),
    surfaceVariant = Color(0xFF334155),
    onSurfaceVariant = Color(0xFFCBD5E1)
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
