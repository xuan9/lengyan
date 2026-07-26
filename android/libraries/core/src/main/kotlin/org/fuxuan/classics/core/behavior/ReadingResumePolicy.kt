package org.fuxuan.classics.core.behavior

enum class ReadingMode {
    CHAPTER,
    PAGED,
    TREE,
}

data class ReadingResumeSnapshot(
    val mode: ReadingMode,
    val path: String?,
    val pageIndex: Int?,
    val chapter: Int?,
    val chapterOffset: Double?,
)

sealed interface ReadingResumeTarget {
    data class Chapter(
        val chapter: Int,
        val chapterOffset: Double,
    ) : ReadingResumeTarget

    data class Paged(
        val path: String,
        val pageIndex: Int,
    ) : ReadingResumeTarget

    data class Tree(val path: String) : ReadingResumeTarget
}

object ReadingResumePolicy {
    fun target(
        snapshot: ReadingResumeSnapshot,
        volumeCount: Int,
    ): ReadingResumeTarget? {
        return when (snapshot.mode) {
            ReadingMode.CHAPTER -> {
                val chapter = snapshot.chapter?.takeIf { it in 0 until volumeCount }
                    ?: return null
                val rawOffset = snapshot.chapterOffset ?: 0.0
                val offset = rawOffset.takeIf { it.isFinite() && it > 0 } ?: 0.0
                ReadingResumeTarget.Chapter(chapter = chapter, chapterOffset = offset)
            }
            ReadingMode.PAGED -> validPath(snapshot.path)?.let { path ->
                ReadingResumeTarget.Paged(
                    path = path,
                    pageIndex = (snapshot.pageIndex ?: 0).coerceAtLeast(0),
                )
            }
            ReadingMode.TREE -> validPath(snapshot.path)?.let(ReadingResumeTarget::Tree)
        }
    }

    private fun validPath(path: String?): String? =
        path?.takeIf { it.isNotEmpty() && it != "/" }
}
