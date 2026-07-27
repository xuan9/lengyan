package org.fuxuan.classics.data.repository

import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.behavior.OutlineDisclosurePolicy
import org.fuxuan.classics.core.behavior.ParagraphTextAnchor
import org.fuxuan.classics.core.behavior.ScriptureSearchNavigationPolicy
import org.fuxuan.classics.core.behavior.SearchDocumentKind
import org.fuxuan.classics.core.behavior.VolumeReadingDocument
import org.fuxuan.classics.core.content.AppleManagedAudioProvider
import org.fuxuan.classics.core.content.AppleOnDemandAudioProvider
import org.fuxuan.classics.core.content.AudioDeliveryPlatform
import org.fuxuan.classics.core.content.DocumentedSourceRole
import org.fuxuan.classics.core.content.HttpsAudioProvider
import org.fuxuan.classics.core.content.ProductPlatformState
import org.fuxuan.classics.core.content.SourceReleaseEligibility
import org.fuxuan.classics.core.content.SourceReviewStatus
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
    fun loadsTheSharedProductBookSourceContentAndAudioContracts() = runBlocking {
        val repository = DefaultBookRepository(source)

        val product = repository.product()
        val book = repository.book()
        val sourceManifest = repository.sourceManifest()
        val traditional = repository.content("zh-Hant")
        val simplified = repository.content("zh-Hans")
        val audio = requireNotNull(repository.audioCatalog())
        val audioDelivery = requireNotNull(repository.audioDelivery())

        assertEquals("lengyan", product.productID)
        assertEquals(ProductPlatformState.PLANNED, product.androidPlatformState)
        assertEquals("lengyanjing", book.bookID)
        assertEquals("legacy-1", book.contentVersion)
        assertEquals(SourceReviewStatus.LEGACY_UNVERIFIED, sourceManifest.reviewStatus)
        assertEquals(SourceReleaseEligibility.BLOCKED, sourceManifest.releaseEligibility)
        assertEquals(2, sourceManifest.sources.size)
        assertEquals(
            listOf(
                DocumentedSourceRole.LEGACY_RUNTIME_INPUT,
                DocumentedSourceRole.COLLATION_REFERENCE,
            ),
            sourceManifest.sources.map { it.role },
        )
        assertEquals(
            "唐 般剌蜜帝譯",
            sourceManifest.sources.last().attribution("zh-Hant"),
        )
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
        assertEquals(AudioDeliveryPlatform.ANDROID, audioDelivery.platform)
        assertEquals(ProductPlatformState.PLANNED, audioDelivery.state)
        assertEquals("audio-artifacts.json", audioDelivery.artifactManifestPath)
        assertEquals(null, audioDelivery.selectedRenditionID)
        assertEquals(emptyList<Any>(), audioDelivery.providers)
        assertEquals(3, audioDelivery.releaseBlockers.size)
    }

    @Test
    fun parsesEverySupportedAudioDeliveryProviderKind() {
        val parser = ClassicsContractParser()
        val iosDelivery = parser.parseAudioDelivery(
            source.readText("Platform/ios/audio-delivery.json"),
        )

        assertEquals(AudioDeliveryPlatform.IOS, iosDelivery.platform)
        assertEquals(ProductPlatformState.PRODUCTION, iosDelivery.state)
        assertEquals(
            listOf(
                AppleOnDemandAudioProvider::class,
                AppleManagedAudioProvider::class,
                HttpsAudioProvider::class,
            ),
            iosDelivery.providers.map { it::class },
        )
    }

    @Test
    fun parsesEveryRegisteredProductAndSourceManifest() {
        val parser = ClassicsContractParser()

        listOf("lengyan", "jingang", "yuanjue", "tanjing").forEach { productID ->
            val product = parser.parseProduct(
                repositoryRoot.resolve("Products/$productID/product.json")
                    .readText(Charsets.UTF_8),
            )
            val manifest = parser.parseSourceManifest(
                repositoryRoot.resolve("Products/$productID/source-manifest.json")
                    .readText(Charsets.UTF_8),
            )

            assertEquals(productID, product.productID)
            assertEquals(ProductPlatformState.PLANNED, product.androidPlatformState)
            assertEquals(productID, manifest.productID)
            assertEquals(SourceReleaseEligibility.BLOCKED, manifest.releaseEligibility)
        }
    }

    @Test
    fun rejectsAnExplicitlyEmptySourceAttributionMap() {
        val invalid = source.readText("source-manifest.json").replace(
            oldValue = "\"sourceHeaderAttribution\": {\n        \"zh-Hant\": \"唐 般剌蜜帝譯\"\n      }",
            newValue = "\"sourceHeaderAttribution\": {}",
        )

        assertThrows(IllegalArgumentException::class.java) {
            ClassicsContractParser().parseSourceManifest(invalid)
        }
    }

    @Test
    fun sourceManifestIsReadOnceAndCached() = runBlocking {
        val reads = mutableMapOf<String, Int>()
        val repository = DefaultBookRepository(
            ContractSource { relativePath ->
                reads[relativePath] = reads.getOrDefault(relativePath, 0) + 1
                source.readText(relativePath)
            },
        )

        val first = repository.sourceManifest()
        val second = repository.sourceManifest()

        assertSame(first, second)
        assertEquals(1, reads["source-manifest.json"])
    }

    @Test
    fun audioDeliveryIsReadOnceAndCached() = runBlocking {
        val reads = mutableMapOf<String, Int>()
        val repository = DefaultBookRepository(
            ContractSource { relativePath ->
                reads[relativePath] = reads.getOrDefault(relativePath, 0) + 1
                source.readText(relativePath)
            },
        )

        val first = repository.audioDelivery()
        val second = repository.audioDelivery()

        assertSame(first, second)
        assertEquals(1, reads["Platform/android/audio-delivery.json"])
        assertEquals(1, reads["audio-artifacts.json"])
    }

    @Test
    fun rejectsAndroidDeliveryThatSelectsAnUnknownRendition() {
        val alteredDelivery = source.readText("Platform/android/audio-delivery.json").replace(
            oldValue = "\"selectedRenditionID\": null",
            newValue = "\"selectedRenditionID\": \"unknown-rendition\"",
        )
        val repository = DefaultBookRepository(
            ContractSource { relativePath ->
                if (relativePath == "Platform/android/audio-delivery.json") {
                    alteredDelivery
                } else {
                    source.readText(relativePath)
                }
            },
        )

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { repository.audioDelivery() }
        }
    }

    @Test
    fun rejectsAndroidDeliveryWhoseStateDisagreesWithTheProduct() {
        val alteredDelivery = source.readText("Platform/android/audio-delivery.json").replace(
            oldValue = "\"state\": \"planned\"",
            newValue = "\"state\": \"retired\"",
        )
        val repository = DefaultBookRepository(
            ContractSource { relativePath ->
                if (relativePath == "Platform/android/audio-delivery.json") {
                    alteredDelivery
                } else {
                    source.readText(relativePath)
                }
            },
        )

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { repository.audioDelivery() }
        }
    }

    @Test
    fun rejectsASourceManifestForAnotherProduct() {
        val wrongProductManifest = source.readText("source-manifest.json").replace(
            oldValue = "\"productID\": \"lengyan\"",
            newValue = "\"productID\": \"jingang\"",
        )
        val repository = DefaultBookRepository(
            ContractSource { relativePath ->
                if (relativePath == "source-manifest.json") {
                    wrongProductManifest
                } else {
                    source.readText(relativePath)
                }
            },
        )

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { repository.sourceManifest() }
        }
    }

    @Test
    fun rejectsContentThatReferencesAnUndocumentedSource() {
        val alteredSourceManifest = source.readText("source-manifest.json").replace(
            oldValue = "lengyan.source.legacy-repository-json",
            newValue = "lengyan.source.undocumented-replacement",
        )
        val repository = DefaultBookRepository(
            ContractSource { relativePath ->
                if (relativePath == "source-manifest.json") {
                    alteredSourceManifest
                } else {
                    source.readText(relativePath)
                }
            },
        )

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { repository.content("zh-Hant") }
        }
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

    @Test
    fun fullyExpandedOutlineReachesEveryRealLeafExactlyOnce() = runBlocking {
        val content = DefaultBookRepository(source).content("zh-Hant")
        val rows = OutlineDisclosurePolicy.visibleRows(
            content = content,
            expandedSectionIDs = OutlineDisclosurePolicy.expandableSectionIDs(content),
        )
        val leafSectionIDs = content.leafSections().map { it.sectionID }
        val visibleLeafSectionIDs = rows
            .filterNot { it.hasChildren }
            .map { it.section.sectionID }

        assertEquals(content.sections.size, rows.size)
        assertEquals(leafSectionIDs, visibleLeafSectionIDs)
        assertEquals(1_155, visibleLeafSectionIDs.size)
        assertEquals(visibleLeafSectionIDs.size, visibleLeafSectionIDs.toSet().size)
    }
}
