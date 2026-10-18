package com.dingdongbuddy.companion

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

/**
 * Android notification channels, one per reminder kind. Users can change each
 * channel's sound, vibration and Do Not Disturb behaviour in system settings,
 * which is the per-kind control Web Push cannot offer.
 *
 * Channel sound and vibration are frozen once a channel exists, so changing
 * the bundled defaults requires a new channel id (bump the `_v` suffix).
 */
object AgentNotifications {
    const val CHANNEL_COMPLETION = "agent_completion_v2"
    const val CHANNEL_ATTENTION = "agent_attention_v2"
    const val CHANNEL_CONNECTION = "relay_connection_v1"
    private const val GROUP_AGENT = "agent"

    const val EXTRA_ROOM = "com.dingdongbuddy.companion.ROOM"
    const val EXTRA_ACTIVITY_ID = "com.dingdongbuddy.companion.ACTIVITY_ID"

    private val completionVibration = longArrayOf(0, 120, 80, 120)
    private val attentionVibration = longArrayOf(0, 300, 150, 300, 150, 600)

    fun ensureChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannelGroup(NotificationChannelGroup(GROUP_AGENT, "Agent 提醒"))
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val completion = NotificationChannel(
            CHANNEL_COMPLETION,
            "Agent 完成",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Agent 完成一轮任务时提醒。"
            group = GROUP_AGENT
            setSound(rawUri(context, "agent_completion"), audio)
            enableVibration(true)
            vibrationPattern = completionVibration
            setShowBadge(true)
        }
        val attention = NotificationChannel(
            CHANNEL_ATTENTION,
            "Agent 需要你处理",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Agent 等待你确认、授权或回答问题时提醒。"
            group = GROUP_AGENT
            setSound(rawUri(context, "agent_attention"), audio)
            enableVibration(true)
            vibrationPattern = attentionVibration
            enableLights(true)
            setShowBadge(true)
        }
        val connection = NotificationChannel(
            CHANNEL_CONNECTION,
            "连接状态",
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "保持与电脑的加密连接，用于及时收到 Agent 提醒。"
            setShowBadge(false)
        }
        manager.createNotificationChannels(listOf(completion, attention, connection))
        retiredChannels.forEach(manager::deleteNotificationChannel)
    }

    /** v1 stored sounds by numeric resource id; see [rawUri]. */
    private val retiredChannels = listOf("agent_completion_v1", "agent_attention_v1")

    fun canPost(context: Context): Boolean =
        (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED) &&
            context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    /** Posts the event on its kind's channel; silent events are only recorded. */
    fun show(context: Context, event: AgentEvent, room: String, hostName: String): Boolean {
        if (event.silent || !canPost(context)) return false
        val channel = when (event.kind) {
            AgentNotificationKind.ATTENTION -> CHANNEL_ATTENTION
            AgentNotificationKind.COMPLETION -> CHANNEL_COMPLETION
        }
        val notificationId = event.id.hashCode()
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ROOM, room)
            putExtra(EXTRA_ACTIVITY_ID, event.activityId)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            notificationId,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = Notification.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(event.displayTitle)
            .setContentText(event.body)
            .setStyle(Notification.BigTextStyle().bigText(event.body))
            .setSubText(hostName)
            .setCategory(
                if (event.kind == AgentNotificationKind.ATTENTION) {
                    Notification.CATEGORY_REMINDER
                } else {
                    Notification.CATEGORY_STATUS
                },
            )
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
        context.getSystemService(NotificationManager::class.java).notify(notificationId, builder.build())
        return true
    }

    // Name-based, not R.raw ids: the channel stores this URI forever, and
    // numeric resource ids can change between builds.
    private fun rawUri(context: Context, name: String): Uri =
        Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/raw/$name")
}
