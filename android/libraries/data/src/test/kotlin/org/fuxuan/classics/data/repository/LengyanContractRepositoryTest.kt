package org.fuxuan.classics.data.repository

import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.behavior.ParagraphTextAnchor
import org.fuxuan.classics.core.behavior.ScriptureSearchNavigationPolicy
import org.fuxuan.classics.core.behavior.SearchDocumentKind
import org.fuxuan.classics.core.behavior.VolumeReadingDocument
import org.fuxuan.classics.data.contracts.ClassicsContractParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.File

class LengyanContractRepositoryTest {
    private val repositoryRoot = File(
        requireNotNull(System.getProperty("classics.repositoryRoot")) {
            "Gradle must provide classics.repositoryRoot"
        },
    ).canonicalFile
    private val productRoot = repositoryRoot.resolve("Products/lengyan").canonicalFile
    private val source = ContractSource { relativePath ->
        val file = productRoot.resolve(relativePath).canonicalFile
        require(file.toPath().startsWith(productRoot.toPath())) { "test asset escaped product root" }
        file.readText(Charsets.UTF_8)
    }

    @Test
    fun loadsTheSharedProductBookContentAndAudioContracts() = runBlocking {
        val repository = DefaultBookRepository(source)

        val product = repository.product()
        val book = repository.book()
        val traditional = repository.content("zh-Hant")
        val simplified = repository.content("zh-Hans")
        val audio = requireNotNull(repository.audioCatalog())

        assertEquals("lengyan", product.productID)
        assertEquals("lengyanjing", book.bookID)
        assertEquals("legacy-1", book.contentVersion)
        assertEquals(10, traditional.volumes.size)
        assertEquals(1_669, traditional.sections.size)
        assertEquals(1_262, traditional.paragraphs.size)
        assertEquals(0, traditional.paragraphs.count { it.volumeID == null })
        assertEquals(
            traditional.volumes.map { it.volumeID },
            simplified.volumes.map { it.volumeID },
        )
        assertEquals(
            traditional.sections.map { it.sectionID },
            simplified.sections.map { it.sectionID },
        )
        assertEquals(
            traditional.paragraphs.map { it.paragraphID },
            simplified.paragraphs.map { it.paragraphID },
        )

        val mappedVolumeIDs = audio.artifacts.mapNotNull { it.contentMapping.volumeID }.toSet()
        assertEquals(traditional.volumes.map { it.volumeID }.toSet(), mappedVolumeIDs)
        assertEquals(1, audio.artifacts.count { it.contentMapping.status == "legacy-unmapped" })
    }

    @Test
    fun rejectsContentWhosePayloadNoLongerMatchesItsHash() {
        val original = source.readText("Content/content-zh-Hant.json")
        val altered = original.replace(
            oldValue = "如是我聞，一時佛在室羅筏城，祇桓精舍。",
            newValue = "如是我聞，一時佛在室羅筏城，祇桓精舍！",
        )

        assertThrows(IllegalArgumentException::class.java) {
            ClassicsContractParser().parseContent(altered)
        }
    }

    @Test
    fun assemblesEveryRealVolumeInCanonicalReadingOrder() = runBlocking {
        val content = DefaultBookRepository(source).content("zh-Hant")
        val coveredParagraphIDs = mutableListOf<String>()
        val documents = content.volumesInReadingOrder().map { volume ->
            val expectedParagraphs = content.paragraphsInReadingOrder()
                .filter { it.volumeID == volume.volumeID }
            coveredParagraphIDs += expectedParagraphs.map { it.paragraphID }
            val document = VolumeReadingDocument.from(content, volume.volumeID)

            assertEquals(expectedParagraphs.joinToString("\n\n") { it.text }, document.text)
            assertEquals(
                ParagraphTextAnchor(expectedParagraphs.first().paragraphID, 0),
                document.anchorAtUtf16Offset(0),
            )
            document
        }

        assertEquals(
            content.paragraphsInReadingOrder().map { it.paragraphID },
            coveredParagraphIDs,
        )
        assertEquals(9_479, documents.maxOf { it.text.length })
    }

    @Test
    fun searchIndexReusesParsedContentAndItsOwnCachedInstance() = runBlocking {
        val reads = mutableMapOf<String, Int>()
        val repository = DefaultBookRepository(
            ContractSource { relativePath ->
                reads[relativePath] = reads.getOrDefault(relativePath, 0) + 1
                source.readText(relativePath)
            },
        )

        repository.content("zh-Hant")
        val firstIndex = repository.searchIndex()
        val secondIndex = repository.searchIndex()

        assertSame(firstIndex, secondIndex)
        assertEquals(1, reads["Content/content-zh-Hant.json"])
        assertEquals(1, reads["Content/content-zh-Hans.json"])
    }

    @Test
    fun searchResultsResolveToReadableTargetsAndExactCharacterOffsets() = runBlocking {
        val repository = DefaultBookRepository(source)
        val content = repository.content("zh-Hant")
        val results = repository.searchIndex().search(
            query = "转物",
            displayLocale = "zh-Hant",
        )
        val paragraphResult = results.first { it.kind == SearchDocumentKind.PARAGRAPH }
        val paragraphTarget = requireNotNull(
            ScriptureSearchNavigationPolicy.target(content, paragraphResult),
        )
        val paragraph = requireNotNull(content.paragraph(paragraphTarget.anchor.paragraphID))
        val matchStart = paragraph.text.offsetByCodePoints(
            0,
            paragraphTarget.anchor.characterOffset,
        )
        val matchEnd = paragraph.text.offsetByCodePoints(
            matchStart,
            paragraphTarget.highlightCharacterCount,
        )

        assertEquals("轉物", paragraph.text.substring(matchStart, matchEnd))
        assertEquals(paragraph.volumeID, paragraphTarget.volumeID)
        assertEquals(2, paragraphTarget.highlightCharacterCount)

        val sectionResult = results.first { it.kind == SearchDocumentKind.SECTION }
        val sectionTarget = requireNotNull(
            ScriptureSearchNavigationPolicy.target(content, sectionResult),
        )
        assertEquals(
            content.firstParagraphInSubtree(sectionResult.sectionID)?.paragraphID,
            sectionTarget.anchor.paragraphID,
        )
        assertEquals(0, sectionTarget.highlightCharacterCount)
        content.sections.forEach { section ->
            assertNotNull(
                "section ${section.sectionID} does not lead to readable text",
                content.firstParagraphInSubtree(section.sectionID),
            )
        }
    }
}
