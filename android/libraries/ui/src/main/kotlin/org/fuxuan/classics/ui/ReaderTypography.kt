package org.fuxuan.classics.ui

import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

internal data class ReaderTypography(
    val fontSize: TextUnit,
    val lineHeight: TextUnit,
)

internal fun readerTypography(level: Int): ReaderTypography = when (level) {
    0 -> ReaderTypography(fontSize = 20.sp, lineHeight = 35.sp)
    1 -> ReaderTypography(fontSize = 22.sp, lineHeight = 39.sp)
    2 -> ReaderTypography(fontSize = 24.sp, lineHeight = 42.sp)
    3 -> ReaderTypography(fontSize = 27.sp, lineHeight = 47.sp)
    4 -> ReaderTypography(fontSize = 30.sp, lineHeight = 53.sp)
    else -> error("unsupported font size level: $level")
}
