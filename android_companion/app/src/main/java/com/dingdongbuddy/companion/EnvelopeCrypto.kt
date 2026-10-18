package com.dingdongbuddy.companion

import org.json.JSONObject
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * The device-link envelope shared with the PWA (docs/app/app-codecs.js) and the
 * desktop (secure_message_codec.dart): base64url(nonce[12] || AES-256-GCM
 * ciphertext || tag[16]) over the UTF-8 JSON message.
 */
class EnvelopeCrypto(secret: String) {
    private val key = SecretKeySpec(Base64Url.decode(secret), "AES")
    private val secretBytes = Base64Url.decode(secret)

    fun seal(message: JSONObject): String {
        val nonce = ByteArray(nonceBytes).also { random.nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(tagBits, nonce))
        val encrypted = cipher.doFinal(message.toString().toByteArray(Charsets.UTF_8))
        return Base64Url.encode(nonce + encrypted)
    }

    fun open(envelope: String): JSONObject {
        require(envelope.length <= maximumEnvelopeChars) { "envelope too large" }
        val value = Base64Url.decode(envelope)
        require(value.size >= nonceBytes + tagBits / 8) { "envelope too short" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            key,
            GCMParameterSpec(tagBits, value, 0, nonceBytes),
        )
        val clear = cipher.doFinal(value, nonceBytes, value.size - nonceBytes)
        return JSONObject(String(clear, Charsets.UTF_8))
    }

    /** Bearer token the relay uses to authorize push registration (`pushToken`). */
    fun pushToken(): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secretBytes, "HmacSHA256"))
        return Base64Url.encode(mac.doFinal("dingdong-push-v1".toByteArray(Charsets.UTF_8)))
    }

    companion object {
        const val maximumEnvelopeChars = 256 * 1024
        private const val nonceBytes = 12
        private const val tagBits = 128
        private val random = SecureRandom()
    }
}
