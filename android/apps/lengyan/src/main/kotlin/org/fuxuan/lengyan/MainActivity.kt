package org.fuxuan.lengyan

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.fuxuan.classics.core.behavior.LegacyVerseDeepLinkParser
import org.fuxuan.classics.core.behavior.ScriptureDeepLink
import org.fuxuan.classics.ui.ClassicsApp
import org.fuxuan.classics.widget.DAILY_VERSE_PARAGRAPH_ID_EXTRA

class MainActivity : ComponentActivity() {
    private lateinit var deepLinkParser: LegacyVerseDeepLinkParser
    private var pendingDeepLink by mutableStateOf<ScriptureDeepLink?>(null)
    private var acceptedDeepLinkRequestKey: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as LengyanApplication).container
        deepLinkParser = LegacyVerseDeepLinkParser(
            productID = container.product.productID,
            scheme = container.product.productID,
        )
        val restoredPath = savedInstanceState?.getString(PENDING_DEEP_LINK_PATH_KEY)
        val restoredParagraphID = savedInstanceState?.getString(PENDING_PARAGRAPH_ID_KEY)
        acceptedDeepLinkRequestKey = savedInstanceState
            ?.getString(ACCEPTED_DEEP_LINK_REQUEST_KEY)
        val restoredCharacterOffset = savedInstanceState
            ?.getInt(PENDING_CHARACTER_OFFSET_KEY, 0)
            ?: 0
        pendingDeepLink = when {
            restoredParagraphID != null -> ScriptureDeepLink(
                productID = container.product.productID,
                paragraphID = restoredParagraphID,
                characterOffset = restoredCharacterOffset,
            )
            restoredPath != null -> ScriptureDeepLink(
                productID = container.product.productID,
                legacyPath = restoredPath,
            )
            else -> null
        }
        acceptDeepLink(intent, ignorePreviouslyAccepted = savedInstanceState != null)

        setContent {
            ClassicsApp(
                container = container,
                pendingDeepLink = pendingDeepLink,
                onDeepLinkConsumed = { consumed ->
                    if (pendingDeepLink == consumed) pendingDeepLink = null
                },
                onDarkThemeChanged = ::applyEdgeToEdge,
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        acceptDeepLink(intent, ignorePreviouslyAccepted = false)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        pendingDeepLink?.let { deepLink ->
            deepLink.legacyPath?.let { path ->
                outState.putString(PENDING_DEEP_LINK_PATH_KEY, path)
            }
            deepLink.paragraphID?.let { paragraphID ->
                outState.putString(PENDING_PARAGRAPH_ID_KEY, paragraphID)
                outState.putInt(PENDING_CHARACTER_OFFSET_KEY, deepLink.characterOffset)
            }
        }
        acceptedDeepLinkRequestKey?.let { requestKey ->
            outState.putString(ACCEPTED_DEEP_LINK_REQUEST_KEY, requestKey)
        }
        super.onSaveInstanceState(outState)
    }

    private fun acceptDeepLink(
        intent: Intent?,
        ignorePreviouslyAccepted: Boolean,
    ) {
        val requestKey = intent?.deepLinkRequestKey() ?: return
        if (ignorePreviouslyAccepted && requestKey == acceptedDeepLinkRequestKey) return
        val productID = (application as LengyanApplication).container.product.productID
        intent.dataString
            ?.let(deepLinkParser::parse)
            ?.let {
                pendingDeepLink = it
                acceptedDeepLinkRequestKey = requestKey
                return
            }
        intent.getStringExtra(EXTRA_PARAGRAPH_ID)
            ?.takeIf(String::isNotBlank)
            ?.let { paragraphID ->
                pendingDeepLink = ScriptureDeepLink(
                    productID = productID,
                    paragraphID = paragraphID,
                    characterOffset = intent.getIntExtra(EXTRA_CHARACTER_OFFSET, 0)
                        .coerceAtLeast(0),
                )
                acceptedDeepLinkRequestKey = requestKey
            }
    }

    private fun Intent.deepLinkRequestKey(): String? {
        dataString?.let { return "uri:$it" }
        val paragraphID = getStringExtra(EXTRA_PARAGRAPH_ID)
            ?.takeIf(String::isNotBlank)
            ?: return null
        val offset = getIntExtra(EXTRA_CHARACTER_OFFSET, 0).coerceAtLeast(0)
        val requestID = getLongExtra(EXTRA_DEEP_LINK_REQUEST_ID, 0).coerceAtLeast(0)
        return "paragraph:$paragraphID:$offset:$requestID"
    }

    private fun applyEdgeToEdge(darkTheme: Boolean) {
        val transparent = Color.TRANSPARENT
        val style = if (darkTheme) {
            SystemBarStyle.dark(transparent)
        } else {
            SystemBarStyle.light(transparent, transparent)
        }
        enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }

    companion object {
        internal const val EXTRA_PARAGRAPH_ID = DAILY_VERSE_PARAGRAPH_ID_EXTRA
        internal const val EXTRA_CHARACTER_OFFSET =
            "org.fuxuan.classics.extra.SCRIPTURE_CHARACTER_OFFSET"
        internal const val EXTRA_DEEP_LINK_REQUEST_ID =
            "org.fuxuan.classics.extra.DEEP_LINK_REQUEST_ID"
        const val PENDING_DEEP_LINK_PATH_KEY = "pendingDeepLinkPath"
        const val PENDING_PARAGRAPH_ID_KEY = "pendingParagraphID"
        const val PENDING_CHARACTER_OFFSET_KEY = "pendingCharacterOffset"
        const val ACCEPTED_DEEP_LINK_REQUEST_KEY = "acceptedDeepLinkRequestKey"
    }
}
