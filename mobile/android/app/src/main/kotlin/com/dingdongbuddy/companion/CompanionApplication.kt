package com.dingdongbuddy.companion

import android.app.Application

/**
 * Creates the notification channels for every process start, including a
 * boot-time service start that never shows the activity.
 */
class CompanionApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        CompanionChannels.ensure(this)
    }
}
