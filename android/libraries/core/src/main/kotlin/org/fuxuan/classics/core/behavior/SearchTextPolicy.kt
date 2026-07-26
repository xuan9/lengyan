package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent

fun interface SearchTextNormalizer {
    fun normalize(text: String): String
}

data class SearchTextMatch(
    val characterOffset: Int,
    val characterCount: Int,
) {
    init {
        require(characterOffset >= 0) { "search match offset must not be negative" }
        require(characterCount > 0) { "search match length must be positive" }
    }
}

class AlignedScriptNormalizer private constructor(
    private val characterMap: Map<Int, Int>,
) : SearchTextNormalizer {
    override fun normalize(text: String): String = buildString(text.length) {
        text.codePoints().forEach { codePoint ->
            appendCodePoint(characterMap[codePoint] ?: codePoint)
        }
    }

    companion object {
        fun fromContents(
            traditional: ScriptureContent,
            simplified: ScriptureContent,
        ): AlignedScriptNormalizer {
            require(traditional.productID == simplified.productID) { "content products do not match" }
            require(traditional.bookID == simplified.bookID) { "content books do not match" }
            require(traditional.editionID == simplified.editionID) { "content editions do not match" }

            val pairs = buildList {
                requireSameIDs(
                    traditional.volumes.map { it.volumeID },
                    simplified.volumes.map { it.volumeID },
                    "volume",
                )
                traditional.volumes.zip(simplified.volumes).forEach { (hant, hans) ->
                    add(hant.title to hans.title)
                }

                requireSameIDs(
                    traditional.sections.map { it.sectionID },
                    simplified.sections.map { it.sectionID },
                    "section",
                )
                traditional.sections.zip(simplified.sections).forEach { (hant, hans) ->
                    add(hant.title to hans.title)
                    if (hant.subtitle != null || hans.subtitle != null) {
                        add(hant.subtitle.orEmpty() to hans.subtitle.orEmpty())
                    }
                }

                requireSameIDs(
                    traditional.paragraphs.map { it.paragraphID },
                    simplified.paragraphs.map { it.paragraphID },
                    "paragraph",
                )
                traditional.paragraphs.zip(simplified.paragraphs).forEach { (hant, hans) ->
                    add(hant.text to hans.text)
                }
            }

            val candidates = mutableMapOf<Int, MutableMap<Int, Int>>()
            pairs.forEach { (hant, hans) ->
                val traditionalCodePoints = hant.codePointList()
                val simplifiedCodePoints = hans.codePointList()
                require(traditionalCodePoints.size == simplifiedCodePoints.size) {
                    "aligned script strings must preserve character count"
                }
                traditionalCodePoints.zip(simplifiedCodePoints).forEach { (source, target) ->
                    val counts = candidates.getOrPut(source) { mutableMapOf() }
                    counts[target] = counts.getOrDefault(target, 0) + 1
                }
            }

            val mapping = candidates.mapValues { (_, counts) ->
                counts.entries
                    .sortedWith(compareByDescending<Map.Entry<Int, Int>> { it.value }.thenBy { it.key })
                    .first()
                    .key
            }
            return AlignedScriptNormalizer(mapping)
        }

        private fun requireSameIDs(
            traditionalIDs: List<String>,
            simplifiedIDs: List<String>,
            label: String,
        ) {
            require(traditionalIDs == simplifiedIDs) { "$label IDs differ between scripts" }
        }
    }
}

object SearchTextPolicy {
    fun normalized(
        text: String,
        normalizer: SearchTextNormalizer,
    ): String = normalizer.normalize(text)

    fun matches(
        text: String,
        query: String,
        normalizer: SearchTextNormalizer,
    ): Boolean = match(text, query, normalizer) != null

    fun match(
        text: String,
        query: String,
        normalizer: SearchTextNormalizer,
    ): SearchTextMatch? {
        val normalizedQuery = normalized(query, normalizer)
            .codePointList()
        if (normalizedQuery.isEmpty()) return null
        val matchStart = normalized(text, normalizer)
            .codePointList()
            .indexOfSubsequence(normalizedQuery)
        if (matchStart < 0) return null
        return SearchTextMatch(
            characterOffset = matchStart,
            characterCount = normalizedQuery.size,
        )
    }

    fun snippet(
        text: String,
        query: String,
        maxLength: Int,
        normalizer: SearchTextNormalizer,
    ): String {
        require(maxLength > 0) { "search snippet length must be positive" }
        val match = match(text, query, normalizer)
            ?: return text.codePointList().take(maxLength).toCodePointString()
        return snippet(text = text, match = match, maxLength = maxLength)
    }

    fun snippet(
        text: String,
        match: SearchTextMatch,
        maxLength: Int,
    ): String {
        require(maxLength > 0) { "search snippet length must be positive" }
        val original = text.codePointList()
        require(
            match.characterCount <= original.size &&
                match.characterOffset <= original.size - match.characterCount,
        ) {
            "search match exceeds text length"
        }
        val matchStart = match.characterOffset
        val matchEnd = matchStart + match.characterCount
        val start = (matchStart - maxLength / 3).coerceAtLeast(0)
        val end = (matchEnd + maxLength * 2 / 3).coerceAtMost(original.size)
        var adjusted = original.subList(start, end)
            .toCodePointString()
            .replace('\n', ' ')
        if (start > 0) {
            adjusted = smartTruncateFront(
                text = adjusted,
                matchStart = matchStart - start,
            )
        }
        adjusted = trimLeadingPunctuation(adjusted)

        val adjustedCodePoints = adjusted.codePointList()
        return if (adjustedCodePoints.size > maxLength) {
            adjustedCodePoints.take(maxLength).toCodePointString() + "..."
        } else {
            adjusted
        }
    }

    private fun smartTruncateFront(
        text: String,
        matchStart: Int,
    ): String {
        val original = text.codePointList()
        val cut = (0 until matchStart)
            .lastOrNull { index -> original[index] in BREAK_CHARACTERS }
            ?.plus(1)
            ?: return text
        if (cut >= matchStart) return text
        return original.drop(cut).toCodePointString()
    }

    private fun trimLeadingPunctuation(text: String): String {
        val characters = text.codePointList()
        return characters.dropWhile(LEADING_PUNCTUATION::contains).toCodePointString()
    }

    private val BREAK_CHARACTERS = "，。、；：！？…—（《」』\\ ".codePointList().toSet()
    private val LEADING_PUNCTUATION = "，。、；：！？…—）」』》 ,".codePointList().toSet()
}

private fun String.codePointList(): List<Int> = codePoints().toArray().toList()

private fun List<Int>.toCodePointString(): String = buildString(size) {
    this@toCodePointString.forEach(::appendCodePoint)
}

private fun List<Int>.indexOfSubsequence(query: List<Int>): Int {
    if (query.isEmpty() || query.size > size) return -1
    for (start in 0..size - query.size) {
        if (query.indices.all { offset -> this[start + offset] == query[offset] }) return start
    }
    return -1
}
