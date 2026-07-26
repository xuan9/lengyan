package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent

enum class SearchDocumentKind {
    SECTION,
    PARAGRAPH,
}

data class ScriptureSearchResult(
    val documentID: String,
    val sectionID: String,
    val paragraphID: String?,
    val kind: SearchDocumentKind,
    val displayText: String,
    val snippet: String,
    val matchCharacterOffset: Int,
    val matchCharacterCount: Int,
) {
    init {
        require(documentID.isNotBlank()) { "search documentID must not be blank" }
        require(sectionID.isNotBlank()) { "search sectionID must not be blank" }
        require(displayText.isNotEmpty()) { "search display text must not be empty" }
        require(snippet.isNotEmpty()) { "search snippet must not be empty" }
        require(matchCharacterOffset >= 0) { "search match offset must not be negative" }
        require(matchCharacterCount > 0) { "search match length must be positive" }
        val displayCharacterCount = displayText.codePointCount(0, displayText.length)
        require(
            matchCharacterCount <= displayCharacterCount &&
                matchCharacterOffset <= displayCharacterCount - matchCharacterCount,
        ) { "search match exceeds display text" }
        when (kind) {
            SearchDocumentKind.SECTION -> require(paragraphID == null) {
                "section search result cannot contain paragraphID"
            }
            SearchDocumentKind.PARAGRAPH -> require(!paragraphID.isNullOrBlank()) {
                "paragraph search result requires paragraphID"
            }
        }
    }
}

class ScriptureSearchIndex(
    traditional: ScriptureContent,
    simplified: ScriptureContent,
) {
    private val normalizer = AlignedScriptNormalizer.fromContents(traditional, simplified)
    private val documents: List<SearchDocument>

    init {
        val simplifiedSections = simplified.sections.associateBy { it.sectionID }
        val simplifiedParagraphs = simplified.paragraphs.associateBy { it.paragraphID }
        documents = buildList {
            fun appendSection(sectionID: String) {
                val hant = requireNotNull(traditional.section(sectionID))
                val hans = requireNotNull(simplifiedSections[sectionID])
                add(
                    SearchDocument(
                        documentID = hant.sectionID,
                        sectionID = hant.sectionID,
                        paragraphID = null,
                        kind = SearchDocumentKind.SECTION,
                        traditionalText = hant.title,
                        simplifiedText = hans.title,
                    ),
                )
                traditional.paragraphsIn(sectionID).forEach { traditionalParagraph ->
                    val simplifiedParagraph = requireNotNull(
                        simplifiedParagraphs[traditionalParagraph.paragraphID],
                    )
                    add(
                        SearchDocument(
                            documentID = traditionalParagraph.paragraphID,
                            sectionID = traditionalParagraph.sectionID,
                            paragraphID = traditionalParagraph.paragraphID,
                            kind = SearchDocumentKind.PARAGRAPH,
                            traditionalText = traditionalParagraph.text,
                            simplifiedText = simplifiedParagraph.text,
                        ),
                    )
                }
                traditional.childrenOf(sectionID).forEach { child ->
                    appendSection(child.sectionID)
                }
            }
            traditional.rootSections().forEach { root -> appendSection(root.sectionID) }
        }
    }

    fun search(
        query: String,
        displayLocale: String,
        maxSnippetLength: Int = 50,
        limit: Int = 100,
    ): List<ScriptureSearchResult> {
        if (query.isEmpty() || limit <= 0) return emptyList()
        return documents.asSequence()
            .mapNotNull { document ->
                val displayText = if (displayLocale == "zh-Hans") {
                    document.simplifiedText
                } else {
                    document.traditionalText
                }
                val alternateText = if (displayLocale == "zh-Hans") {
                    document.traditionalText
                } else {
                    document.simplifiedText
                }
                val match = SearchTextPolicy.match(displayText, query, normalizer)
                    ?: SearchTextPolicy.match(alternateText, query, normalizer)
                    ?: return@mapNotNull null
                ScriptureSearchResult(
                    documentID = document.documentID,
                    sectionID = document.sectionID,
                    paragraphID = document.paragraphID,
                    kind = document.kind,
                    displayText = displayText,
                    snippet = SearchTextPolicy.snippet(
                        text = displayText,
                        match = match,
                        maxLength = maxSnippetLength,
                    ),
                    matchCharacterOffset = match.characterOffset,
                    matchCharacterCount = match.characterCount,
                )
            }
            .take(limit)
            .toList()
    }

    fun textNormalizer(): SearchTextNormalizer = normalizer

    private data class SearchDocument(
        val documentID: String,
        val sectionID: String,
        val paragraphID: String?,
        val kind: SearchDocumentKind,
        val traditionalText: String,
        val simplifiedText: String,
    )
}
