package org.fuxuan.classics.data.repository

import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.data.contracts.ClassicsContractParser
import org.junit.Assert.assertEquals
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
        assertEquals(22, traditional.paragraphs.count { it.volumeID == null })
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
}
