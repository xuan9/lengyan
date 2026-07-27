package org.fuxuan.classics.widget

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.first
import org.fuxuan.classics.core.AppContainer
import org.fuxuan.classics.core.behavior.DailyVerseSelectionPolicy
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.persistence.ThemePreference
import java.time.Clock

data class DailyVerseWidgetContent(
    val productTitle: String,
    val header: String,
    val text: String,
    val source: String,
    val paragraphID: String?,
    val theme: ThemePreference,
    val tapHint: String,
) {
    fun accessibilityDescription(displayText: String = text): String =
        listOf(productTitle, displayText, source, tapHint)
            .filter(String::isNotBlank)
            .joinForAccessibility()
}

enum class DailyVerseWidgetLayout(
    val textLimit: Int,
    val maxLines: Int,
    val bodyFontSize: Int,
) {
    COMPACT(textLimit = 58, maxLines = 3, bodyFontSize = 17),
    MEDIUM(textLimit = 120, maxLines = 4, bodyFontSize = 18),
    TALL(textLimit = 90, maxLines = 7, bodyFontSize = 19),
    EXPANDED(textLimit = 300, maxLines = 11, bodyFontSize = 19),
    ;

    companion object {
        fun forSize(widthDp: Float, heightDp: Float): DailyVerseWidgetLayout = when {
            widthDp < 240f && heightDp >= 220f -> TALL
            heightDp >= 220f -> EXPANDED
            widthDp >= 250f && heightDp >= 140f -> MEDIUM
            else -> COMPACT
        }
    }
}

object DailyVerseWidgetTextPolicy {
    fun normalized(text: String): String = text
        .replace(WHITESPACE, " ")
        .trim()

    fun displayText(text: String, limit: Int): String {
        require(limit > 1) { "daily verse limit must leave room for text" }
        val normalized = normalized(text)
        val codePoints = normalized.codePoints().toArray()
        if (codePoints.size <= limit) return normalized

        val head = String(codePoints, 0, limit)
        lastIndexOfAny(head, SENTENCE_ENDINGS)?.let { endingIndex ->
            return head.substring(0, endingIndex + 1)
        }
        lastIndexOfAny(head, PHRASE_ENDINGS)?.let { endingIndex ->
            return head.substring(0, endingIndex).trimEnd() + ELLIPSIS
        }
        return String(codePoints, 0, limit - 1) + ELLIPSIS
    }

    fun shortLabel(text: String, limit: Int): String {
        require(limit > 1) { "daily verse label limit must leave room for text" }
        val normalized = normalized(text)
        val codePoints = normalized.codePoints().toArray()
        return if (codePoints.size <= limit) {
            normalized
        } else {
            String(codePoints, 0, limit - 1) + ELLIPSIS
        }
    }

    private fun lastIndexOfAny(text: String, characters: Set<Char>): Int? =
        text.indexOfLast(characters::contains).takeIf { it >= 0 }

    private val WHITESPACE = Regex("\\s+")
    private val SENTENCE_ENDINGS = setOf('。', '；', '！', '？', '!', '?')
    private val PHRASE_ENDINGS = setOf('，', '、', ',', ';')
    private const val ELLIPSIS = "…"
}

class DailyVerseWidgetDataLoader(
    private val clock: Clock = Clock.systemDefaultZone(),
) {
    suspend fun load(
        container: AppContainer,
        stateStore: DailyVerseWidgetStateStore? = null,
    ): DailyVerseWidgetContent {
        val instant = clock.instant()
        val localDate = instant.atZone(clock.zone).toLocalDate()
        val preferences = container.userPreferencesRepository.preferences.first()
        val product = container.bookRepository.product()
        check(product.features.dailyVerse) { "product does not enable daily verse" }
        val book = container.bookRepository.book()
        val content = container.bookRepository.content(preferences.locale)
        val favoriteParagraphIDs = container.favoriteRepository.favorites(book.editionID)
            .first()
            .mapNotNull { it.paragraphID }
        val candidateIDs = (product.featuredParagraphIDs + favoriteParagraphIDs)
            .distinct()
            .filter { content.paragraph(it) != null }
        val proposedID = DailyVerseSelectionPolicy.selectedID(
            productID = product.productID,
            contentVersion = book.contentVersion,
            instant = instant,
            timeZone = clock.zone,
            candidateIDs = candidateIDs,
            excludedID = preferences.readingProgress?.paragraphID,
        ) ?: error("daily verse product has no available candidate")
        val selectedID = stateStore?.lockedSelectionID(
            productID = product.productID,
            contentVersion = book.contentVersion,
            localDate = localDate,
            proposedID = proposedID,
            isParagraphAvailable = { content.paragraph(it) != null },
        ) ?: proposedID
        val paragraph = requireNotNull(content.paragraph(selectedID)) {
            "daily verse selection is missing from content"
        }
        val simplified = preferences.locale == "zh-Hans"

        val result = DailyVerseWidgetContent(
            productTitle = product.title(preferences.locale),
            header = if (simplified) "今日读经" else "今日讀經",
            text = DailyVerseWidgetTextPolicy.normalized(paragraph.text),
            source = sourceLabel(content, paragraph),
            paragraphID = paragraph.paragraphID,
            theme = preferences.theme,
            tapHint = if (simplified) "点击阅读" else "點按閱讀",
        )
        if (stateStore != null) {
            try {
                stateStore.saveSnapshot(
                    productID = product.productID,
                    contentVersion = book.contentVersion,
                    localDate = localDate,
                    content = result,
                )
            } catch (exception: CancellationException) {
                throw exception
            } catch (_: Exception) {
                // The live content remains usable even when its fallback snapshot cannot be saved.
            }
        }
        return result
    }

    private fun sourceLabel(
        content: ScriptureContent,
        paragraph: ScriptureParagraph,
    ): String {
        val volumeTitle = paragraph.volumeID?.let(content::volume)?.title
        val sectionTitle = content.sectionPath(paragraph.sectionID).lastOrNull()?.title
        return listOfNotNull(volumeTitle, sectionTitle)
            .filter(String::isNotBlank)
            .distinct()
            .joinToString(" · ")
            .let { DailyVerseWidgetTextPolicy.shortLabel(it, SOURCE_LABEL_LIMIT) }
    }

    private companion object {
        const val SOURCE_LABEL_LIMIT = 32
    }
}

private fun List<String>.joinForAccessibility(): String = buildString {
    this@joinForAccessibility.forEach { part ->
        if (isNotEmpty() && last() !in ACCESSIBILITY_PUNCTUATION) append('。')
        append(part)
    }
}

private val ACCESSIBILITY_PUNCTUATION = setOf(
    '。', '，', '、', '；', '：', '！', '？',
    '.', ',', ';', ':', '!', '?',
)
