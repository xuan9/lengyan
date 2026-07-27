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
        pendingDeepLink = when {
            restoredParagraphID != null -> ScriptureDeepLink(
                productID = container.product.productID,
                paragraphID = restoredParagraphID,
            )
            restoredPath != null -> ScriptureDeepLink(
                productID = container.product.productID,
                legacyPath = restoredPath,
            )
            else -> null
        }
        if (savedInstanceState == null) acceptDeepLink(intent)

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
        acceptDeepLink(intent)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        pendingDeepLink?.let { deepLink ->
            deepLink.legacyPath?.let { path ->
                outState.putString(PENDING_DEEP_LINK_PATH_KEY, path)
            }
            deepLink.paragraphID?.let { paragraphID ->
                outState.putString(PENDING_PARAGRAPH_ID_KEY, paragraphID)
            }
        }
        super.onSaveInstanceState(outState)
    }

    private fun acceptDeepLink(intent: Intent?) {
        val productID = (application as LengyanApplication).container.product.productID
        intent?.dataString
            ?.let(deepLinkParser::parse)
            ?.let {
                pendingDeepLink = it
                return
            }
        intent?.getStringExtra(EXTRA_PARAGRAPH_ID)
            ?.takeIf(String::isNotBlank)
            ?.let { paragraphID ->
                pendingDeepLink = ScriptureDeepLink(
                    productID = productID,
                    paragraphID = paragraphID,
                )
            }
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
        const val PENDING_DEEP_LINK_PATH_KEY = "pendingDeepLinkPath"
        const val PENDING_PARAGRAPH_ID_KEY = "pendingParagraphID"
    }
}
