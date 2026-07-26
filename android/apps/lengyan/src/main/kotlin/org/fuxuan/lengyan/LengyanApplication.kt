package org.fuxuan.lengyan

import android.app.Application

class LengyanApplication : Application() {
    val container: LengyanAppContainer by lazy(LazyThreadSafetyMode.NONE) {
        LengyanAppContainer()
    }
}
