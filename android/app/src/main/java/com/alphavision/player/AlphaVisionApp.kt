package com.alphavision.player

import android.app.Application
import com.alphavision.player.data.AppContainer

class AlphaVisionApp : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
