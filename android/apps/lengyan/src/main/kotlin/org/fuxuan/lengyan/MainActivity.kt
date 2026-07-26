package org.fuxuan.lengyan

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import org.fuxuan.classics.ui.ClassicsApp
import org.fuxuan.classics.ui.ClassicsTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as LengyanApplication).container

        setContent {
            ClassicsTheme {
                ClassicsApp(product = container.product)
            }
        }
    }
}
