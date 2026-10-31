package com.dingdongbuddy.companion

import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri

/**
 * Android notification channels, one per reminder kind, created natively so
 * their sounds are frozen as name-based URIs (verified in the Kotlin
 * prototype). Dart posts to these ids through flutter_local_notifications.
 *
 * Channel sound and vibration cannot change after creation: to ship new
 * defaults, add a new id and move the old one to [retiredChannels].
 */
object CompanionChannels {
    const val COMPLETION = "agent_completion_v2"
    const val ATTENTION = "agent_attention_v2"
    const val CONNECTION = "relay_connection_v1"
    private const val GROUP_AGENT = "agent"
    private val retiredChannels = listOf("agent_completion_v1", "agent_attention_v1")

    fun ensure(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannelGroup(NotificationChannelGroup(GROUP_AGENT, "Agent 提醒"))
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val completion = NotificationChannel(
            COMPLETION,
            "Agent 完成",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Agent 完成一轮任务时提醒。"
            group = GROUP_AGENT
            setSound(rawUri(context, "agent_completion"), audio)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 120, 80, 120)
            setShowBadge(true)
        }
        val attention = NotificationChannel(
            ATTENTION,
            "Agent 需要你处理",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Agent 等待你确认、授权或回答问题时提醒。"
            group = GROUP_AGENT
            setSound(rawUri(context, "agent_attention"), audio)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 300, 150, 300, 150, 600)
            enableLights(true)
            setShowBadge(true)
        }
        val connection = NotificationChannel(
            CONNECTION,
            "连接状态",
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "保持与电脑的加密连接，用于及时收到 Agent 提醒。"
            setShowBadge(false)
            setSound(null, null)
        }
        manager.createNotificationChannels(listOf(completion, attention, connection))
        retiredChannels.forEach(manager::deleteNotificationChannel)
    }

    // Name-based, not R.raw ids: the channel stores this URI forever, and
    // numeric resource ids can change between builds.
    private fun rawUri(context: Context, name: String): Uri =
        Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/raw/$name")
}
