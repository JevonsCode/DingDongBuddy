package com.dingdongbuddy.companion

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Keeps one relay socket per paired computer alive in a foreground service.
 * This is the prototype's delivery channel: it needs no push credentials and
 * no relay changes, at the cost of a persistent status notification.
 */
class RelayService : Service(), RelayConnection.Listener {
    private val connections = mutableMapOf<String, RelayConnection>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var store: CompanionStore
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onCreate() {
        super.onCreate()
        store = CompanionStore(this)
        AgentNotifications.ensureChannels(this)
        running = this
        registerNetworkCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        when (intent?.action) {
            ACTION_SEEN -> {
                val room = intent.getStringExtra(AgentNotifications.EXTRA_ROOM)
                val activityId = intent.getStringExtra(AgentNotifications.EXTRA_ACTIVITY_ID)
                if (room != null && activityId != null) connections[room]?.markSeen(listOf(activityId))
            }
            else -> syncConnections()
        }
        if (connections.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        networkCallback?.let {
            getSystemService(ConnectivityManager::class.java).unregisterNetworkCallback(it)
        }
        connections.values.forEach { it.close() }
        connections.clear()
        states.clear()
        if (running === this) running = null
        notifyUi()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun syncConnections() {
        val pairings = store.pairings().associateBy { it.room }
        (connections.keys - pairings.keys).forEach { room ->
            connections.remove(room)?.close()
            states.remove(room)
        }
        pairings.values.filter { it.room !in connections }.forEach { pairing ->
            val connection = RelayConnection(pairing, ::identity, this)
            connections[pairing.room] = connection
            connection.connect()
        }
        notifyUi()
    }

    private fun identity(): JSONObject = JSONObject()
        .put("id", store.deviceId)
        .put("name", store.deviceName)
        .put("kind", "phone")
        .put("platform", "android")

    override fun onStateChanged(room: String, state: LinkState) {
        states[room] = state
        mainHandler.post {
            updateForegroundNotification()
            notifyUi()
        }
    }

    override fun onHostName(room: String, hostName: String) {
        store.updateHostName(room, hostName)
        mainHandler.post { notifyUi() }
    }

    override fun onMessage(pairing: Pairing, message: JSONObject) {
        val event = AgentEvent.parse(message) ?: return
        if (!store.markNotified(event.id)) return
        val shown = AgentNotifications.show(this, event, pairing.room, pairing.hostName)
        store.recordEvent(event.toRecord(pairing.hostName).put("shown", shown))
        Log.i(TAG, "agent.completed ${event.id} kind=${event.kind} silent=${event.silent} shown=$shown")
        mainHandler.post { notifyUi() }
    }

    private fun startInForeground() {
        val notification = foregroundNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(FOREGROUND_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(FOREGROUND_ID, notification)
        }
    }

    private fun updateForegroundNotification() {
        if (connections.isEmpty()) return
        getSystemService(NotificationManager::class.java).notify(FOREGROUND_ID, foregroundNotification())
    }

    private fun foregroundNotification(): Notification {
        val connected = states.values.count { it == LinkState.CONNECTED }
        val total = maxOf(connections.size, store.pairings().size)
        val text = when {
            total == 0 -> "未连接电脑"
            connected == total -> "已连接 $connected 台电脑，Agent 提醒实时送达"
            connected > 0 -> "已连接 $connected / $total 台电脑"
            else -> "等待电脑上线…"
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = Notification.Builder(this, AgentNotifications.CHANNEL_CONNECTION)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("DingDong")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(open)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun registerNetworkCallback() {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                mainHandler.post { connections.values.forEach { it.nudge() } }
            }
        }
        getSystemService(ConnectivityManager::class.java).registerDefaultNetworkCallback(callback)
        networkCallback = callback
    }

    companion object {
        private const val TAG = "DingDongCompanion"
        private const val FOREGROUND_ID = 1
        private const val ACTION_SEEN = "com.dingdongbuddy.companion.SEEN"

        @Volatile
        private var running: RelayService? = null
        private val states = java.util.concurrent.ConcurrentHashMap<String, LinkState>()
        private val uiListeners = CopyOnWriteArraySet<() -> Unit>()

        fun state(room: String): LinkState? = states[room]

        fun isRunning(): Boolean = running != null

        fun addListener(listener: () -> Unit) = uiListeners.add(listener)

        fun removeListener(listener: () -> Unit) = uiListeners.remove(listener)

        private fun notifyUi() = uiListeners.forEach { it() }

        /** Starts or re-syncs the service with the stored pairings. */
        fun sync(context: Context) {
            if (CompanionStore(context).pairings().isEmpty() && running == null) return
            context.startForegroundService(Intent(context, RelayService::class.java))
        }

        fun markSeen(context: Context, room: String, activityId: String) {
            if (running == null) return
            context.startForegroundService(
                Intent(context, RelayService::class.java)
                    .setAction(ACTION_SEEN)
                    .putExtra(AgentNotifications.EXTRA_ROOM, room)
                    .putExtra(AgentNotifications.EXTRA_ACTIVITY_ID, activityId),
            )
        }
    }
}
