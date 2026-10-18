package com.dingdongbuddy.companion

import android.content.Context
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * App-private persistence. Prototype note: pairing secrets live in private
 * SharedPreferences (excluded from backup in the manifest). A release build
 * should wrap them with an Android Keystore key.
 */
class CompanionStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences("dingdong-companion", Context.MODE_PRIVATE)
    private val appContext = context.applicationContext

    val deviceId: String
        get() = prefs.getString(KEY_DEVICE_ID, null) ?: UUID.randomUUID().toString().also {
            prefs.edit().putString(KEY_DEVICE_ID, it).apply()
        }

    var deviceName: String
        get() = prefs.getString(KEY_DEVICE_NAME, null) ?: defaultDeviceName()
        set(value) {
            prefs.edit().putString(KEY_DEVICE_NAME, value.trim().take(80)).apply()
        }

    fun pairings(): List<Pairing> {
        val array = JSONArray(prefs.getString(KEY_PAIRINGS, "[]"))
        return (0 until array.length()).mapNotNull { Pairing.fromJson(array.getJSONObject(it)) }
    }

    /** Adds or replaces the computer for this room; one room per computer. */
    @Synchronized
    fun savePairing(pairing: Pairing) {
        val next = pairings().filter { it.room != pairing.room && it.hostId != pairing.hostId } + pairing
        writePairings(next)
    }

    @Synchronized
    fun removePairing(room: String) {
        writePairings(pairings().filter { it.room != room })
    }

    @Synchronized
    fun updateHostName(room: String, hostName: String) {
        val name = hostName.trim().take(80)
        if (name.isEmpty()) return
        writePairings(pairings().map { if (it.room == room) it.copy(hostName = name) else it })
    }

    private fun writePairings(values: List<Pairing>) {
        val array = JSONArray()
        values.forEach { array.put(it.toJson()) }
        prefs.edit().putString(KEY_PAIRINGS, array.toString()).apply()
    }

    /**
     * Returns true the first time an Agent message id is seen. The desktop can
     * deliver one event over the realtime socket and again on reconnect.
     */
    @Synchronized
    fun markNotified(messageId: String): Boolean {
        val array = JSONArray(prefs.getString(KEY_NOTIFIED, "[]"))
        val ids = (0 until array.length()).map { array.getString(it) }
        if (messageId in ids) return false
        val next = (ids + messageId).takeLast(200)
        prefs.edit().putString(KEY_NOTIFIED, JSONArray(next).toString()).apply()
        return true
    }

    @Synchronized
    fun recordEvent(event: JSONObject) {
        val array = JSONArray(prefs.getString(KEY_EVENTS, "[]"))
        val next = JSONArray().put(event)
        for (index in 0 until minOf(array.length(), 29)) next.put(array.getJSONObject(index))
        prefs.edit().putString(KEY_EVENTS, next.toString()).apply()
    }

    fun recentEvents(): List<JSONObject> {
        val array = JSONArray(prefs.getString(KEY_EVENTS, "[]"))
        return (0 until array.length()).map { array.getJSONObject(it) }
    }

    private fun defaultDeviceName(): String {
        val configured = Settings.Global.getString(appContext.contentResolver, "device_name")
        if (!configured.isNullOrBlank()) return configured.trim().take(80)
        val model = Build.MODEL.orEmpty()
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val name = if (model.startsWith(manufacturer, ignoreCase = true)) model else "$manufacturer $model"
        return name.trim().ifEmpty { "Android 手机" }.take(80)
    }

    companion object {
        private const val KEY_DEVICE_ID = "device-id"
        private const val KEY_DEVICE_NAME = "device-name"
        private const val KEY_PAIRINGS = "pairings"
        private const val KEY_NOTIFIED = "notified-ids"
        private const val KEY_EVENTS = "recent-events"
    }
}
