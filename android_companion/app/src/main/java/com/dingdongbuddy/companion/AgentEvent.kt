package com.dingdongbuddy.companion

import org.json.JSONObject

enum class AgentNotificationKind { COMPLETION, ATTENTION }

/**
 * A decoded `agent.completed` message. Field meaning and fallbacks match the
 * PWA (docs/app/notification-policy.js and service-worker.js).
 */
data class AgentEvent(
    val id: String,
    val activityId: String?,
    val kind: AgentNotificationKind,
    val silent: Boolean,
    val vibrate: Boolean,
    val title: String,
    val body: String,
    val source: String,
    val completedAt: String?,
) {
    /** Notification title, prefixed with the Agent source like the PWA. */
    val displayTitle: String
        get() = if (source.isEmpty() || title.lowercase().contains(source.lowercase())) {
            title
        } else {
            "$source · $title"
        }

    fun toRecord(hostName: String): JSONObject = JSONObject()
        .put("id", id)
        .put("kind", kind.name.lowercase())
        .put("silent", silent)
        .put("title", displayTitle)
        .put("body", body)
        .put("host", hostName)
        .put("receivedAt", System.currentTimeMillis())

    companion object {
        private const val maximumBodyCharacters = 260

        fun parse(message: JSONObject): AgentEvent? {
            if (message.optString("type") != "agent.completed") return null
            val id = message.optString("id")
            if (id.isEmpty() || id.length > 160) return null
            val kind = if (
                message.optBoolean("needsUserAttention", false) ||
                message.optString("notificationKind") == "attention"
            ) {
                AgentNotificationKind.ATTENTION
            } else {
                AgentNotificationKind.COMPLETION
            }
            val title = normalized(message.optString("title")).ifEmpty {
                if (kind == AgentNotificationKind.ATTENTION) "Agent 需要你处理" else "Agent 完成啦"
            }
            val task = normalized(message.optString("task"))
            val detail = normalized(message.optString("detail")).ifEmpty {
                normalized(message.optString("summary"))
            }
            val fallback = if (kind == AgentNotificationKind.ATTENTION) {
                "请打开 Agent 提醒查看并继续处理。"
            } else {
                "本轮任务已经完成。"
            }
            val body = when {
                task.isNotEmpty() && detail.isNotEmpty() && task != detail -> "$task：$detail"
                detail.isNotEmpty() -> detail
                task.isNotEmpty() -> task
                else -> fallback
            }
            return AgentEvent(
                id = id,
                activityId = message.optString("activityId").ifEmpty { null },
                kind = kind,
                // The desktop's per-kind rules mark reminders that should keep
                // the in-app list current without raising a system alert.
                silent = message.optBoolean("silent", false),
                vibrate = message.optBoolean("vibrate", true),
                title = title,
                body = truncate(body, maximumBodyCharacters),
                source = normalized(message.optString("source")),
                completedAt = message.optString("completedAt").ifEmpty { null },
            )
        }

        private fun normalized(value: String): String = value.replace(Regex("\\s+"), " ").trim()

        private fun truncate(value: String, maximum: Int): String {
            val codePoints = value.codePointCount(0, value.length)
            if (codePoints <= maximum) return value
            val end = value.offsetByCodePoints(0, maximum - 1)
            return value.substring(0, end) + "…"
        }
    }
}
