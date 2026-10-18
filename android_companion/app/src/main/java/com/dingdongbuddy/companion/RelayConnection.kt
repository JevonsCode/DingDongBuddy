package com.dingdongbuddy.companion

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.os.HandlerCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.util.concurrent.TimeUnit

enum class LinkState { CONNECTING, WAITING_FOR_COMPUTER, CONNECTED, REPLACED, OFFLINE }

/**
 * One encrypted relay session with a paired computer, joining the room as the
 * `peer` side exactly like the PWA (docs/app/app-connection.js). The companion
 * never answers WebRTC offers; after `welcome` it asks the desktop to keep
 * this device on the relay so the desktop stops offering a data channel.
 */
class RelayConnection(
    private val pairing: Pairing,
    private val identity: () -> JSONObject,
    private val listener: Listener,
) {
    interface Listener {
        fun onStateChanged(room: String, state: LinkState)
        fun onMessage(pairing: Pairing, message: JSONObject)
        fun onHostName(room: String, hostName: String)
    }

    private val crypto = EnvelopeCrypto(pairing.secret)
    private val handler = Handler(Looper.getMainLooper())
    private var socket: WebSocket? = null
    private var generation = 0
    private var reconnectDelayMs = INITIAL_RECONNECT_MS
    private var helloSent = false
    private var closed = false

    @Volatile
    var state: LinkState = LinkState.OFFLINE
        private set

    val room: String get() = pairing.room

    fun connect() {
        handler.post {
            if (closed || socket != null) return@post
            open()
        }
    }

    /** Reconnects now, e.g. when the network comes back. */
    fun nudge() {
        handler.post {
            if (closed) return@post
            if (socket == null || state == LinkState.OFFLINE) {
                handler.removeCallbacksAndMessages(RECONNECT_TOKEN)
                reconnectDelayMs = INITIAL_RECONNECT_MS
                socket?.cancel()
                socket = null
                open()
            }
        }
    }

    fun close() {
        handler.post {
            closed = true
            handler.removeCallbacksAndMessages(RECONNECT_TOKEN)
            generation += 1
            socket?.close(1000, "Companion closed")
            socket = null
            setState(LinkState.OFFLINE)
        }
    }

    fun send(message: JSONObject): Boolean {
        val current = socket ?: return false
        if (state != LinkState.CONNECTED && message.optString("type") != "hello") return false
        val frame = JSONObject().put("type", "data").put("payload", crypto.seal(message)).toString()
        if (frame.length > MAXIMUM_FRAME_CHARS) return false
        return current.send(frame)
    }

    private fun open() {
        val currentGeneration = ++generation
        helloSent = false
        setState(LinkState.CONNECTING)
        val request = Request.Builder().url(roomUrl()).build()
        socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) {
                handler.post {
                    if (currentGeneration != generation) return@post
                    handleFrame(text)
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(code, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                handler.post { onSocketEnded(currentGeneration, code, reason) }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.w(TAG, "Relay connection to ${pairing.hostName} failed: ${t.message}")
                handler.post { onSocketEnded(currentGeneration, null, null) }
            }
        })
    }

    private fun onSocketEnded(endedGeneration: Int, code: Int?, reason: String?) {
        if (endedGeneration != generation || closed) return
        socket = null
        helloSent = false
        if (code == 1008 && reason.equals(REPLACED_REASON, ignoreCase = true)) {
            // Another client joined this room as the peer. Reconnecting would
            // start a replacement loop, so wait for the user instead.
            setState(LinkState.REPLACED)
            return
        }
        setState(LinkState.OFFLINE)
        HandlerCompat.postDelayed(
            handler,
            { if (!closed && socket == null) open() },
            RECONNECT_TOKEN,
            reconnectDelayMs,
        )
        reconnectDelayMs = (reconnectDelayMs * 1.7).toLong().coerceAtMost(MAXIMUM_RECONNECT_MS)
    }

    private fun handleFrame(raw: String) {
        if (raw.length > MAXIMUM_FRAME_CHARS) return
        val frame = try {
            JSONObject(raw)
        } catch (_: org.json.JSONException) {
            return
        }
        when (frame.optString("type")) {
            "relay" -> when (frame.optString("event")) {
                "ready" -> if (state == LinkState.CONNECTING) setState(LinkState.WAITING_FOR_COMPUTER)
                "host_joined" -> {
                    reconnectDelayMs = INITIAL_RECONNECT_MS
                    sendHello()
                }
                "host_left" -> {
                    helloSent = false
                    setState(LinkState.WAITING_FOR_COMPUTER)
                }
            }
            "data" -> {
                val payload = frame.optString("payload")
                if (payload.isEmpty()) return
                val message = try {
                    crypto.open(payload)
                } catch (error: Exception) {
                    Log.w(TAG, "Dropped an envelope that did not decrypt: ${error.javaClass.simpleName}")
                    return
                }
                handleMessage(message)
            }
            // "signal" frames carry WebRTC offers; the companion stays on the relay.
        }
    }

    private fun sendHello() {
        if (helloSent) return
        helloSent = true
        val hello = JSONObject()
            .put("type", "hello")
            .put("device", identity())
            .put("vibrationEnabled", true)
            .put("agentNotificationsEnabled", true)
        if (!send(hello)) helloSent = false
    }

    private fun handleMessage(message: JSONObject) {
        when (message.optString("type")) {
            "welcome" -> {
                setState(LinkState.CONNECTED)
                message.optJSONObject("host")?.optString("name")?.takeIf { it.isNotBlank() }?.let {
                    listener.onHostName(pairing.room, it)
                }
                send(
                    JSONObject()
                        .put("type", "settings.update")
                        .put("agentNotificationsEnabled", true)
                        .put("vibrationEnabled", true)
                        .put("transportPreference", "serviceRelay"),
                )
            }
            else -> listener.onMessage(pairing, message)
        }
    }

    fun markSeen(activityIds: List<String>) {
        if (activityIds.isEmpty()) return
        handler.post {
            send(JSONObject().put("type", "agent.seen").put("activityIds", JSONArray(activityIds)))
        }
    }

    private fun setState(next: LinkState) {
        if (state == next) return
        state = next
        listener.onStateChanged(pairing.room, next)
    }

    private fun roomUrl(): String {
        val base = URI(pairing.relay)
        val scheme = if (base.scheme == "https") "wss" else "ws"
        val path = base.rawPath.orEmpty().trimEnd('/') + "/v1/rooms/" + pairing.room
        val port = if (base.port == -1) "" else ":${base.port}"
        return "$scheme://${base.host}$port$path?side=peer"
    }

    companion object {
        private const val TAG = "DingDongRelay"
        private const val REPLACED_REASON = "Replaced by a newer connection"
        private const val INITIAL_RECONNECT_MS = 1_000L
        private const val MAXIMUM_RECONNECT_MS = 60_000L
        private const val MAXIMUM_FRAME_CHARS = 256 * 1024
        private val RECONNECT_TOKEN = Any()

        // A WebSocket ping keeps NAT/Cloudflare idle timers from silently
        // dropping the socket and lets OkHttp detect a dead connection.
        private val client: OkHttpClient = OkHttpClient.Builder()
            .pingInterval(25, TimeUnit.SECONDS)
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .build()
    }
}
