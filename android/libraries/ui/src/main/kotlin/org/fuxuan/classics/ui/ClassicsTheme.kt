package org.fuxuan.classics.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF466B3C),
    onPrimary = Color.White,
    secondary = Color(0xFF7A3E48),
    background = Color(0xFFF8F8F5),
    surface = Color(0xFFFFFFFF),
    onBackground = Color(0xFF20231F),
    onSurface = Color(0xFF20231F),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFAACD9D),
    onPrimary = Color(0xFF183713),
    secondary = Color(0xFFFFB2BE),
    background = Color(0xFF151713),
    surface = Color(0xFF1C1F1A),
    onBackground = Color(0xFFE5E4DE),
    onSurface = Color(0xFFE5E4DE),
)

@Composable
fun ClassicsTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
