package org.fuxuan.classics.data.contracts

import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import org.fuxuan.classics.core.behavior.AudioPlaybackResumePolicy
import org.fuxuan.classics.core.behavior.AudioStartDecision
import org.fuxuan.classics.core.behavior.DailyVerseSelectionPolicy
import org.fuxuan.classics.core.behavior.LegacyFavoritesMigrationPolicy
import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.behavior.LegacyVerseDeepLinkParser
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.behavior.ReadingResumePolicy
import org.fuxuan.classics.core.behavior.ReadingResumeSnapshot
import org.fuxuan.classics.core.behavior.ReadingResumeTarget
import org.fuxuan.classics.core.behavior.ScriptureSearchIndex
import org.fuxuan.classics.core.behavior.SearchTextPolicy
import org.fuxuan.classics.core.behavior.ShareFileKind
import org.fuxuan.classics.core.behavior.ShareFileNamePolicy
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.FavoriteRepository
import org.fuxuan.classics.data.persistence.LegacyFavoritesImporter
import org.fuxuan.classics.data.repository.ContractSource
import org.fuxuan.classics.data.repository.DefaultBookRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.Instant
import java.time.ZoneId

class BehaviorContractTest {
    private val repositoryRoot = File(
        requireNotNull(System.getProperty("classics.repositoryRoot")) {
            "Gradle must provide classics.repositoryRoot"
        },
    ).canonicalFile
    private val productRoot = repositoryRoot.resolve("Products/lengyan").canonicalFile
    private val json = Json {
        ignoreUnknownKeys = false
        explicitNulls = false
    }
    private val repository = DefaultBookRepository(
        ContractSource { relativePath ->
            val file = productRoot.resolve(relativePath).canonicalFile
            require(file.toPath().startsWith(productRoot.toPath())) {
                "test asset escaped product root"
            }
            file.readText(Charsets.UTF_8)
        },
    )

    @Test
    fun audioStartFixturesMatchProductionPolicy() {
        val fixture = fixture<AudioStartInput, AudioStartExpected>(
            "audio-start-decision.json",
            "audio-start-decision",
        )

        fixture.cases.forEach { case ->
            val actual = when (
                val decision = AudioPlaybackResumePolicy.startDecision(
                    savedArtifactID = case.input.savedArtifactID,
                    requestedArtifactID = case.input.requestedArtifactID,
                    savedTimeSeconds = case.input.savedTimeSeconds,
                )
            ) {
                AudioStartDecision.Beginning -> AudioStartExpected(startMode = "beginning")
                is AudioStartDecision.Resume -> AudioStartExpected(
                    startMode = "resume",
                    seekTimeSeconds = decision.seekTimeSeconds,
                )
            }
            assertEquals(case.name, case.expected, actual)
        }
    }

    @Test
    fun dailyVerseFixturesMatchProductionPolicy() {
        val fixture = fixture<DailyVerseInput, DailyVerseExpected>(
            "daily-verse-selection.json",
            "daily-verse-selection",
        )

        fixture.cases.forEach { case ->
            val instant = Instant.parse(case.input.instant)
            val timeZone = ZoneId.of(case.input.timeZone)
            val actual = DailyVerseExpected(
                localDate = DailyVerseSelectionPolicy.localDate(instant, timeZone).toString(),
                selectedID = DailyVerseSelectionPolicy.selectedID(
                    productID = case.input.productID,
                    contentVersion = case.input.contentVersion,
                    instant = instant,
                    timeZone = timeZone,
                    candidateIDs = case.input.candidateIDs,
                    excludedID = case.input.excludedID,
                ),
            )
            assertEquals(case.name, case.expected, actual)
        }
    }

    @Test
    fun deepLinkFixturesMatchTheLengyanAdapter() {
        val fixture = fixture<DeepLinkInput, DeepLinkExpected>(
            "deep-link.json",
            "deep-link",
        )
        val parser = LegacyVerseDeepLinkParser(productID = "lengyan", scheme = "lengyan")

        fixture.cases.forEach { case ->
            val link = parser.parse(case.input.url)
            val actual = DeepLinkExpected(
                accepted = link != null,
                productID = link?.productID,
                legacyPath = link?.legacyPath,
            )
            assertEquals(case.name, case.expected, actual)
        }
    }

    @Test
    fun legacyFavoriteFixturesMatchProductionPolicy() = runBlocking {
        val fixture = fixture<LegacyFavoritesInput, LegacyFavoritesExpected>(
            "legacy-favorites-migration.json",
            "legacy-favorites-migration",
        )

        fixture.cases.forEach { case ->
            val actual = LegacyFavoritesExpected(
                userLikes = LegacyFavoritesMigrationPolicy.userFavorites(
                    legacyFavorites = case.input.legacyLikes,
                    storedUserFavorites = case.input.storedUserLikes,
                    curatedLegacyPaths = case.input.curatedLegacyPaths.toSet(),
                ),
            )
            assertEquals(case.name, case.expected, actual)

            val favorites = RecordingFavoriteRepository()
            LegacyFavoritesImporter(
                productID = "lengyan",
                bookRepository = repository,
                favoriteRepository = favorites,
            ).replaceFromLegacy(
                editionID = repository.book().editionID,
                legacyFavorites = case.input.legacyLikes,
                storedUserFavorites = case.input.storedUserLikes,
                curatedLegacyPaths = case.input.curatedLegacyPaths.toSet(),
                importedAtEpochMilliseconds = 1_721_600_000_000,
            )
            assertEquals(
                case.name,
                case.expected.userLikes,
                favorites.stored.mapNotNull(Favorite::legacyPath),
            )
        }
    }

    @Test
    fun legacyLocationFixturesUseTheGeneratedMap() = runBlocking {
        val fixture = fixture<LegacyLocationInput, LegacyLocationExpected>(
            "legacy-location-resolution.json",
            "legacy-location-resolution",
        )
        val product = repository.product()

        fixture.cases.forEach { case ->
            assertEquals(case.name, product.productID, case.input.productID)
            val usage = when (case.input.usage) {
                "favorite" -> LegacyLocationUsage.FAVORITE
                "resume" -> LegacyLocationUsage.RESUME
                else -> error("unsupported fixture usage: ${case.input.usage}")
            }
            val actual = when (
                val resolution = repository.resolveLegacyLocation(case.input.legacyPath, usage)
            ) {
                LegacyLocationResolution.Invalid -> LegacyLocationExpected(status = "invalid")
                LegacyLocationResolution.Unresolved -> LegacyLocationExpected(status = "unresolved")
                is LegacyLocationResolution.Mapped -> LegacyLocationExpected(
                    status = "mapped",
                    sectionID = resolution.sectionID,
                    paragraphID = resolution.paragraphID,
                )
            }
            assertEquals(case.name, case.expected, actual)
        }
    }

    @Test
    fun readingResumeFixturesMatchProductionPolicy() = runBlocking {
        val fixture = fixture<ReadingResumeInput, ReadingResumeExpected>(
            "reading-resume.json",
            "reading-resume",
        )
        val volumeCount = repository.content("zh-Hant").volumes.size

        fixture.cases.forEach { case ->
            val mode = when (case.input.mode) {
                "chapter" -> ReadingMode.CHAPTER
                "paged" -> ReadingMode.PAGED
                "tree" -> ReadingMode.TREE
                else -> error("unsupported fixture mode: ${case.input.mode}")
            }
            val target = ReadingResumePolicy.target(
                snapshot = ReadingResumeSnapshot(
                    mode = mode,
                    path = case.input.path,
                    pageIndex = case.input.pageIndex,
                    chapter = case.input.chapter,
                    chapterOffset = case.input.chapterOffset,
                ),
                volumeCount = volumeCount,
            )
            val actual = ReadingResumeExpected(target = target?.toContract())
            assertEquals(case.name, case.expected, actual)
        }
    }

    @Test
    fun searchFixturesMatchTheSharedContentIndexPolicy() = runBlocking {
        val fixture = fixture<SearchInput, SearchExpected>("search-text.json", "search-text")
        val index = ScriptureSearchIndex(
            traditional = repository.content("zh-Hant"),
            simplified = repository.content("zh-Hans"),
        )
        val normalizer = index.textNormalizer()

        fixture.cases.forEach { case ->
            val matches = SearchTextPolicy.matches(case.input.text, case.input.query, normalizer)
            val actual = SearchExpected(
                normalizedText = SearchTextPolicy.normalized(case.input.text, normalizer),
                normalizedQuery = SearchTextPolicy.normalized(case.input.query, normalizer),
                matches = matches,
                resultPath = case.input.path.takeIf { matches },
                snippet = case.input.text.takeIf { matches }?.let { text ->
                    SearchTextPolicy.snippet(
                        text = text,
                        query = case.input.query,
                        maxLength = case.input.maxLength,
                        normalizer = normalizer,
                    )
                },
            )
            assertEquals(case.name, case.expected, actual)
        }

        val realResults = index.search(query = "转物", displayLocale = "zh-Hant")
        assertTrue(realResults.any { result -> "轉物" in result.displayText })
    }

    @Test
    fun shareFileNameFixturesMatchProductionPolicy() {
        val fixture = fixture<ShareFileNameInput, ShareFileNameExpected>(
            "share-file-name.json",
            "share-file-name",
        )

        fixture.cases.forEach { case ->
            val kind = when (case.input.kind) {
                "image" -> ShareFileKind.IMAGE
                "text" -> ShareFileKind.TEXT
                else -> error("unsupported fixture share kind: ${case.input.kind}")
            }
            val actual = ShareFileNameExpected(
                fileName = ShareFileNamePolicy.fileName(
                    locale = case.input.locale,
                    defaultBaseName = case.input.defaultBaseName,
                    source = case.input.source,
                    kind = kind,
                    uniqueSuffix = case.input.uniqueSuffix,
                    pageNumber = case.input.pageNumber,
                    pageCount = case.input.pageCount,
                ),
            )
            assertEquals(case.name, case.expected, actual)
        }
    }

    private inline fun <reified Input, reified Expected> fixture(
        fileName: String,
        behavior: String,
    ): BehaviorFixture<Input, Expected> {
        val file = repositoryRoot.resolve("Contracts/BehaviorFixtures/$fileName")
        val fixture = json.decodeFromString<BehaviorFixture<Input, Expected>>(
            file.readText(Charsets.UTF_8),
        )
        assertEquals(1, fixture.schemaVersion)
        assertEquals(behavior, fixture.behavior)
        return fixture
    }
}

private class RecordingFavoriteRepository : FavoriteRepository {
    private val state = MutableStateFlow<List<Favorite>>(emptyList())
    val stored: List<Favorite> get() = state.value

    override fun favorites(editionID: String): Flow<List<Favorite>> =
        state.map { favorites -> favorites.filter { it.editionID == editionID } }

    override suspend fun add(favorite: Favorite): Boolean {
        if (state.value.any { it.favoriteID == favorite.favoriteID }) return false
        state.value = listOf(favorite.copy(position = 0)) +
            state.value.mapIndexed { index, existing -> existing.copy(position = index + 1) }
        return true
    }

    override suspend fun remove(editionID: String, favoriteID: String): Boolean {
        val retained = state.value.filterNot {
            it.editionID == editionID && it.favoriteID == favoriteID
        }
        if (retained.size == state.value.size) return false
        state.value = retained.mapIndexed { index, favorite -> favorite.copy(position = index) }
        return true
    }

    override suspend fun replace(editionID: String, favorites: List<Favorite>) {
        state.value = favorites.mapIndexed { index, favorite -> favorite.copy(position = index) }
    }
}

private fun ReadingResumeTarget.toContract(): ReadingResumeTargetContract = when (this) {
    is ReadingResumeTarget.Chapter -> ReadingResumeTargetContract(
        mode = "chapter",
        chapter = chapter,
        chapterOffset = chapterOffset,
    )
    is ReadingResumeTarget.Paged -> ReadingResumeTargetContract(
        mode = "paged",
        path = path,
        pageIndex = pageIndex,
    )
    is ReadingResumeTarget.Tree -> ReadingResumeTargetContract(mode = "tree", path = path)
}

@Serializable
private data class BehaviorFixture<Input, Expected>(
    val schemaVersion: Int,
    val fixtureID: String,
    val behavior: String,
    val cases: List<BehaviorCase<Input, Expected>>,
)

@Serializable
private data class BehaviorCase<Input, Expected>(
    val name: String,
    val input: Input,
    val expected: Expected,
)

@Serializable
private data class AudioStartInput(
    val savedArtifactID: String?,
    val requestedArtifactID: String,
    val savedTimeSeconds: Double,
)

@Serializable
private data class AudioStartExpected(
    val startMode: String,
    val seekTimeSeconds: Double? = null,
)

@Serializable
private data class DailyVerseInput(
    val productID: String,
    val contentVersion: String,
    val instant: String,
    val timeZone: String,
    val candidateIDs: List<String>,
    val excludedID: String?,
)

@Serializable
private data class DailyVerseExpected(
    val localDate: String,
    val selectedID: String?,
)

@Serializable
private data class DeepLinkInput(val url: String)

@Serializable
private data class DeepLinkExpected(
    val accepted: Boolean,
    val productID: String? = null,
    val legacyPath: String? = null,
)

@Serializable
private data class LegacyFavoritesInput(
    val legacyLikes: List<String>,
    val storedUserLikes: List<String>?,
    val curatedLegacyPaths: List<String>,
)

@Serializable
private data class LegacyFavoritesExpected(val userLikes: List<String>)

@Serializable
private data class LegacyLocationInput(
    val productID: String,
    val legacyPath: String,
    val usage: String,
)

@Serializable
private data class LegacyLocationExpected(
    val status: String,
    val sectionID: String? = null,
    val paragraphID: String? = null,
)

@Serializable
private data class ReadingResumeInput(
    val mode: String,
    val path: String?,
    val pageIndex: Int?,
    val chapter: Int?,
    val chapterOffset: Double?,
)

@Serializable
private data class ReadingResumeExpected(val target: ReadingResumeTargetContract?)

@Serializable
private data class ReadingResumeTargetContract(
    val mode: String,
    val path: String? = null,
    val pageIndex: Int? = null,
    val chapter: Int? = null,
    val chapterOffset: Double? = null,
)

@Serializable
private data class SearchInput(
    val text: String,
    val query: String,
    val path: String,
    val maxLength: Int,
)

@Serializable
private data class SearchExpected(
    val normalizedText: String,
    val normalizedQuery: String,
    val matches: Boolean,
    val resultPath: String?,
    val snippet: String?,
)

@Serializable
private data class ShareFileNameInput(
    val locale: String,
    val defaultBaseName: String,
    val source: String?,
    val kind: String,
    val uniqueSuffix: String?,
    val pageNumber: Int? = null,
    val pageCount: Int? = null,
)

@Serializable
private data class ShareFileNameExpected(val fileName: String)
