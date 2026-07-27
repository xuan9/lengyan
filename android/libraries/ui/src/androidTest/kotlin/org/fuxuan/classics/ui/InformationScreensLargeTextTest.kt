package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.fuxuan.classics.core.content.DocumentedSource
import org.fuxuan.classics.core.content.DocumentedSourceArtifact
import org.fuxuan.classics.core.content.DocumentedSourceFormat
import org.fuxuan.classics.core.content.DocumentedSourceRights
import org.fuxuan.classics.core.content.DocumentedSourceRole
import org.fuxuan.classics.core.content.SourceApproval
import org.fuxuan.classics.core.content.SourceApprovalStatus
import org.fuxuan.classics.core.content.SourceApprovals
import org.fuxuan.classics.core.content.SourceCommercialUse
import org.fuxuan.classics.core.content.SourceManifest
import org.fuxuan.classics.core.content.SourceRedistribution
import org.fuxuan.classics.core.content.SourceReleaseEligibility
import org.fuxuan.classics.core.content.SourceReviewStatus
import org.fuxuan.classics.core.content.SourceRightsStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InformationScreensLargeTextTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun sourceInformationRemainsNavigableAtDoubleFontScale() {
        composeRule.setContent {
            val deviceDensity = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(deviceDensity.density, fontScale = 2f),
            ) {
                ClassicsTheme(darkTheme = false) {
                    Box(
                        modifier = Modifier
                            .width(320.dp)
                            .height(700.dp),
                    ) {
                        SourceInfoScreen(
                            manifest = sourceManifest(),
                            productTitle = "楞嚴經",
                            locale = "zh-Hant",
                            strings = AppStrings("zh-Hant"),
                            onBack = {},
                            onOpenExternalUri = {},
                        )
                    }
                }
            }
        }

        composeRule.onNodeWithTag("source.status", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithTag("source.list", useUnmergedTree = true)
            .performScrollToNode(hasTestTag("source.record.test.source.collation"))
        composeRule.onNodeWithText("僅用於校勘，不等於目前正文來源。", useUnmergedTree = true)
            .assertIsDisplayed()
    }

    @Test
    fun privacyInformationRemainsNavigableAtDoubleFontScale() {
        composeRule.setContent {
            val deviceDensity = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(deviceDensity.density, fontScale = 2f),
            ) {
                ClassicsTheme(darkTheme = false) {
                    Box(
                        modifier = Modifier
                            .width(320.dp)
                            .height(700.dp),
                    ) {
                        PrivacyInfoScreen(
                            strings = AppStrings("zh-Hant"),
                            privacyPolicyUri = "https://example.com/privacy",
                            onBack = {},
                            onOpenExternalUri = {},
                        )
                    }
                }
            }
        }

        composeRule.onNodeWithTag("privacy.screen", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithTag("privacy.open-policy", useUnmergedTree = true)
            .performScrollTo()
            .assertIsDisplayed()
    }

    @Test
    fun bundledOpenSourceCatalogCoversEveryLockedRuntimeModule() {
        val document = ThirdPartyNoticeCatalog.load(
            InstrumentationRegistry.getInstrumentation().targetContext.assets,
        )

        assertEquals("android", document.platform)
        assertEquals(147, document.moduleCount)
        assertEquals(8, document.components.size)
        assertEquals(setOf("Apache-2.0"), document.licenses.map { it.licenseID }.toSet())
        assertTrue(document.components.any { it.componentID == "androidx" && it.moduleCount == 131 })
    }

    @Test
    fun openSourceLicensesRemainNavigableAtDoubleFontScale() {
        val document = ThirdPartyNoticeCatalog.load(
            InstrumentationRegistry.getInstrumentation().targetContext.assets,
        )
        composeRule.setContent {
            val deviceDensity = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(deviceDensity.density, fontScale = 2f),
            ) {
                ClassicsTheme(darkTheme = false) {
                    Box(
                        modifier = Modifier
                            .width(320.dp)
                            .height(700.dp),
                    ) {
                        OpenSourceLicensesScreen(
                            document = document,
                            strings = AppStrings("zh-Hant"),
                            onBack = {},
                            onOpenExternalUri = {},
                        )
                    }
                }
            }
        }

        composeRule.onNodeWithTag("licenses.screen", useUnmergedTree = true)
            .assertIsDisplayed()
        composeRule.onNodeWithTag("licenses.list", useUnmergedTree = true)
            .performScrollToNode(hasTestTag("licenses.component.jspecify"))
        composeRule.onNodeWithText("JSpecify", useUnmergedTree = true)
            .assertIsDisplayed()
    }

    @Test
    fun sourceReviewCopyDistinguishesCandidatesFromLegacyRuntimeData() {
        val strings = AppStrings("zh-Hans")
        val candidate = strings.sourceReviewBody(
            SourceReviewStatus.CANDIDATE,
            SourceReleaseEligibility.BLOCKED,
            "测试经典",
        )
        val approvedButBlocked = strings.sourceReviewBody(
            SourceReviewStatus.APPROVED,
            SourceReleaseEligibility.BLOCKED,
            "测试经典",
        )

        assertTrue(candidate.contains("仅为候选"))
        assertFalse(candidate.contains("沿用现有 App"))
        assertTrue(approvedButBlocked.contains("仍有未完成"))
        assertTrue(
            strings.sourceSettingsSubtitle(
                SourceReviewStatus.REJECTED,
                SourceReleaseEligibility.BLOCKED,
            ).contains("未通过"),
        )
    }

    private fun sourceManifest(): SourceManifest = SourceManifest(
        schemaVersion = 1,
        productID = "test",
        bookID = "testbook",
        editionID = "test-edition",
        reviewStatus = SourceReviewStatus.LEGACY_UNVERIFIED,
        releaseEligibility = SourceReleaseEligibility.BLOCKED,
        approvals = SourceApprovals(
            textAccuracy = pendingApproval(),
            rights = pendingApproval(),
        ),
        sources = listOf(
            DocumentedSource(
                sourceID = "test.source.collation",
                role = DocumentedSourceRole.COLLATION_REFERENCE,
                format = DocumentedSourceFormat.TEI_XML,
                title = "校勘參考資料示例",
                institution = "典籍資料機構",
                canonicalIdentifier = "Catalog X0001",
                sourceHeaderAttribution = mapOf("zh-Hant" to "譯者資料示例"),
                sourceURI = "https://example.com/source",
                revision = "fixture",
                retrievedOn = "2026-07-27",
                rights = DocumentedSourceRights(
                    status = SourceRightsStatus.RESTRICTED_NONCOMMERCIAL,
                    commercialUse = SourceCommercialUse.REQUIRES_PERMISSION,
                    redistribution = SourceRedistribution.HEADER_REQUIRED,
                    statement = "Noncommercial collation reference.",
                    statementURI = "https://example.com/rights",
                    licenseIdentifier = null,
                ),
                artifacts = listOf(
                    DocumentedSourceArtifact(
                        locator = "fixtures/collation.xml",
                        pathWithinSource = "fixtures/collation.xml",
                        bytes = 1,
                        sha256 = "0".repeat(64),
                    ),
                ),
            ),
        ),
    )

    private fun pendingApproval() = SourceApproval(
        status = SourceApprovalStatus.PENDING,
        reviewedBy = null,
        reviewedAt = null,
        notes = null,
    )
}
