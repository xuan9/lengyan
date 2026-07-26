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
)

class ScriptureSearchIndex(
    traditional: ScriptureContent,
    simplified: ScriptureContent,
) {
    private val normalizer = AlignedScriptNormalizer.fromContents(traditional, simplified)
    private val documents: List<SearchDocument>

    init {
        val sectionDocuments = traditional.sections.zip(simplified.sections).map { (hant, hans) ->
            SearchDocument(
                documentID = hant.sectionID,
                sectionID = hant.sectionID,
                paragraphID = null,
                kind = SearchDocumentKind.SECTION,
                traditionalText = hant.title,
                simplifiedText = hans.title,
            )
        }
        val paragraphDocuments = traditional.paragraphs.zip(simplified.paragraphs).map { (hant, hans) ->
            SearchDocument(
                documentID = hant.paragraphID,
                sectionID = hant.sectionID,
                paragraphID = hant.paragraphID,
                kind = SearchDocumentKind.PARAGRAPH,
                traditionalText = hant.text,
                simplifiedText = hans.text,
            )
        }
        documents = sectionDocuments + paragraphDocuments
    }

    fun search(
        query: String,
        displayLocale: String,
        maxSnippetLength: Int = 50,
        limit: Int = 100,
    ): List<ScriptureSearchResult> {
        if (query.isEmpty() || limit <= 0) return emptyList()
        return documents.asSequence()
            .filter { document ->
                SearchTextPolicy.matches(document.traditionalText, query, normalizer) ||
                    SearchTextPolicy.matches(document.simplifiedText, query, normalizer)
            }
            .take(limit)
            .map { document ->
                val displayText = if (displayLocale == "zh-Hans") {
                    document.simplifiedText
                } else {
                    document.traditionalText
                }
                ScriptureSearchResult(
                    documentID = document.documentID,
                    sectionID = document.sectionID,
                    paragraphID = document.paragraphID,
                    kind = document.kind,
                    displayText = displayText,
                    snippet = SearchTextPolicy.snippet(
                        text = displayText,
                        query = query,
                        maxLength = maxSnippetLength,
                        normalizer = normalizer,
                    ),
                )
            }
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
