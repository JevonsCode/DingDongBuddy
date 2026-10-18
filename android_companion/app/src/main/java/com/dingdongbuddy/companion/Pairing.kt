package com.dingdongbuddy.companion

import org.json.JSONObject
import java.net.URI

/**
 * One trusted DingDong computer. The fields and their validation mirror the
 * PWA's `isScannedPairing` (docs/app/pairing-state.js) so a desktop QR code is
 * accepted by both clients or by neither.
 */
data class Pairing(
    val room: String,
    val secret: String,
    val relay: String,
    val hostId: String,
    val hostName: String,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("version", 1)
        .put("room", room)
        .put("secret", secret)
        .put("relay", relay)
        .put("hostId", hostId)
        .put("hostName", hostName)

    companion object {
        private val roomPattern = Regex("^[A-Za-z0-9_-]{20,64}$")
        private val secretPattern = Regex("^[A-Za-z0-9_-]{43}$")
        private val fragmentPattern = Regex("#pair=([A-Za-z0-9_-]+)")

        /**
         * Accepts the full link the desktop encodes in its QR code
         * (`https://…/app/#pair=<base64url JSON>`), or any text containing it.
         */
        fun fromLinkText(text: String): Pairing? {
            val raw = fragmentPattern.find(text.trim())?.groupValues?.get(1) ?: return null
            val decoded = try {
                String(Base64Url.decode(raw), Charsets.UTF_8)
            } catch (_: IllegalArgumentException) {
                return null
            }
            return try {
                fromJson(JSONObject(decoded))
            } catch (_: org.json.JSONException) {
                null
            }
        }

        fun fromJson(value: JSONObject): Pairing? {
            val version = if (value.has("version")) value.opt("version") else value.opt("v")
            if (version != 1) return null
            val room = value.optString("room")
            val secret = value.optString("secret")
            val relay = value.optString("relay")
            val hostId = value.optString("hostId")
            val hostName = value.optString("hostName")
            if (!roomPattern.matches(room) || !secretPattern.matches(secret)) return null
            if (hostId.isEmpty() || hostId.length > 160) return null
            if (hostName.isEmpty() || hostName.length > 80) return null
            if (relay.isEmpty() || relay.length > 2048 || !isValidRelay(relay)) return null
            return Pairing(room, secret, relay, hostId, hostName)
        }

        private fun isValidRelay(value: String): Boolean = try {
            val uri = URI(value)
            uri.scheme in setOf("https", "http") &&
                uri.host != null &&
                uri.userInfo == null &&
                uri.rawFragment == null
        } catch (_: Exception) {
            false
        }
    }
}

object Base64Url {
    fun decode(value: String): ByteArray =
        java.util.Base64.getUrlDecoder().decode(value.trimEnd('='))

    fun encode(bytes: ByteArray): String =
        java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
}
