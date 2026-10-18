package com.dingdongbuddy.companion

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import java.text.DateFormat
import java.util.Date

/**
 * Pairing, health checks and per-channel test notifications. Deliberately
 * plain platform views: the companion's value is in the service, not the UI.
 */
class MainActivity : Activity() {
    private lateinit var store: CompanionStore
    private lateinit var content: LinearLayout
    private val refresh: () -> Unit = { runOnUiThread { render() } }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = CompanionStore(this)
        AgentNotifications.ensureChannels(this)
        content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(24), dp(16), dp(32))
        }
        setContentView(ScrollView(this).apply { addView(content) })
        handleIntent(intent)
        RelayService.sync(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        RelayService.addListener(refresh)
        render()
    }

    override fun onPause() {
        RelayService.removeListener(refresh)
        super.onPause()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        render()
    }

    private fun handleIntent(intent: Intent?) {
        intent ?: return
        val room = intent.getStringExtra(AgentNotifications.EXTRA_ROOM)
        val activityId = intent.getStringExtra(AgentNotifications.EXTRA_ACTIVITY_ID)
        if (room != null && activityId != null) {
            RelayService.markSeen(this, room, activityId)
            intent.removeExtra(AgentNotifications.EXTRA_ACTIVITY_ID)
        }
        val text = when (intent.action) {
            Intent.ACTION_VIEW -> intent.dataString
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            else -> null
        } ?: return
        intent.action = null
        val pairing = Pairing.fromLinkText(text)
        if (pairing == null) {
            toast("这个连接二维码无效或已经损坏")
            return
        }
        confirmPairing(pairing)
    }

    private fun render() {
        content.removeAllViews()
        heading("DingDong 手机伴侣", 24f)
        caption("原生接收电脑上的 Agent 提醒：完成与需要你处理分为两个通知渠道，可分别设置铃声与振动。")

        section("提醒健康检查")
        val notificationsOk = AgentNotifications.canPost(this)
        statusRow("系统通知", if (notificationsOk) "已允许" else "未允许", notificationsOk)
        if (!notificationsOk) button("允许通知") { requestNotificationPermission() }
        val power = getSystemService(PowerManager::class.java)
        val unrestricted = power.isIgnoringBatteryOptimizations(packageName)
        statusRow("电池优化", if (unrestricted) "不受限制" else "可能被系统休眠", unrestricted)
        if (!unrestricted) button("允许后台运行") { requestBatteryExemption() }
        statusRow("后台连接服务", if (RelayService.isRunning()) "运行中" else "未运行", RelayService.isRunning())
        if (isXiaomi()) {
            caption("HyperOS 还需要：开启“自启动”，并把省电策略设为“无限制”，否则锁屏后连接可能被系统中断。")
            button("打开自启动管理") { openXiaomiAutostart() }
            button("打开应用省电策略") { openAppDetails() }
        }
        button("通知渠道与铃声设置") { openNotificationSettings() }

        section("已配对的电脑")
        val pairings = store.pairings()
        if (pairings.isEmpty()) caption("还没有配对。在电脑 DingDong 的“连接手机”里显示二维码，然后扫码或粘贴链接。")
        pairings.forEach { pairing ->
            val state = RelayService.state(pairing.room)
            statusRow(pairing.hostName, stateLabel(state), state == LinkState.CONNECTED)
            button("移除 ${pairing.hostName}") {
                AlertDialog.Builder(this)
                    .setTitle("移除“${pairing.hostName}”？")
                    .setMessage("这台手机将不再收到它的 Agent 提醒。电脑端的设备记录需要在电脑上删除。")
                    .setPositiveButton("移除") { _, _ ->
                        store.removePairing(pairing.room)
                        RelayService.sync(this)
                        render()
                    }
                    .setNegativeButton("取消", null)
                    .show()
            }
        }
        button("扫描电脑上的二维码") { scanPairingCode() }
        val linkInput = EditText(this).apply {
            hint = "或粘贴 https://…/app/#pair=… 链接"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setSingleLine(true)
        }
        content.addView(linkInput)
        button("使用这个链接配对") {
            val text = linkInput.text.toString().ifBlank { clipboardText() }
            val pairing = Pairing.fromLinkText(text)
            if (pairing == null) toast("没有找到有效的 DingDong 配对链接") else confirmPairing(pairing)
        }

        section("测试通知")
        caption("在本机直接发出一条测试提醒，用来检查每个渠道的铃声、振动和锁屏显示。")
        button("测试“Agent 完成”") { postTest(AgentNotificationKind.COMPLETION) }
        button("测试“Agent 需要你处理”") { postTest(AgentNotificationKind.ATTENTION) }

        section("最近收到")
        val events = store.recentEvents()
        if (events.isEmpty()) caption("暂无。")
        val format = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT)
        events.take(15).forEach { event ->
            val mode = when {
                event.optBoolean("silent") -> "静默"
                event.optBoolean("shown") -> if (event.optString("kind") == "attention") "需要处理" else "完成"
                else -> "未显示"
            }
            caption(
                "${format.format(Date(event.optLong("receivedAt")))} · ${event.optString("host")} · $mode\n" +
                    "${event.optString("title")}：${event.optString("body")}",
            )
        }
        caption("本机名称：${store.deviceName}\n版本 ${packageManager.getPackageInfo(packageName, 0).versionName}")
    }

    private fun confirmPairing(pairing: Pairing) {
        val existing = store.pairings().any { it.room == pairing.room }
        val nameInput = EditText(this).apply {
            setText(store.deviceName)
            setSingleLine(true)
        }
        AlertDialog.Builder(this)
            .setTitle(if (existing) "重新连接“${pairing.hostName}”？" else "添加“${pairing.hostName}”？")
            .setMessage("这台手机在电脑上显示的名称：")
            .setView(nameInput)
            .setPositiveButton("连接") { _, _ ->
                val name = nameInput.text.toString().trim()
                if (name.isNotEmpty()) store.deviceName = name
                store.savePairing(pairing)
                requestNotificationPermission()
                RelayService.sync(this)
                render()
            }
            .setNegativeButton("取消", null)
            .show()
    }

    private fun scanPairingCode() {
        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        GmsBarcodeScanning.getClient(this, options).startScan()
            .addOnSuccessListener { barcode ->
                val pairing = barcode.rawValue?.let(Pairing::fromLinkText)
                if (pairing == null) toast("这个二维码不是 DingDong 配对码") else confirmPairing(pairing)
            }
            .addOnFailureListener { toast("无法打开扫码：${it.message ?: "Google Play 服务不可用"}") }
    }

    private fun postTest(kind: AgentNotificationKind) {
        if (!AgentNotifications.canPost(this)) {
            requestNotificationPermission()
            return
        }
        val event = AgentEvent(
            id = "test-${System.currentTimeMillis()}",
            activityId = null,
            kind = kind,
            silent = false,
            vibrate = true,
            title = if (kind == AgentNotificationKind.ATTENTION) "Agent 需要你处理" else "Agent 完成啦",
            body = if (kind == AgentNotificationKind.ATTENTION) {
                "测试：Agent 正在等待你的确认。"
            } else {
                "测试：本轮任务已经完成。"
            },
            source = "DingDong",
            completedAt = null,
        )
        AgentNotifications.show(this, event, room = "test", hostName = "本机测试")
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        } else if (!AgentNotifications.canPost(this)) {
            openNotificationSettings()
        }
    }

    private fun requestBatteryExemption() {
        startSafely(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")),
        )
    }

    private fun openNotificationSettings() {
        startSafely(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
    }

    private fun openAppDetails() {
        startSafely(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    }

    private fun openXiaomiAutostart() {
        val intent = Intent().setComponent(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        )
        if (!startSafely(intent)) openAppDetails()
    }

    private fun startSafely(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }

    private fun clipboardText(): String =
        getSystemService(ClipboardManager::class.java).primaryClip
            ?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)?.coerceToText(this)?.toString().orEmpty()

    private fun isXiaomi(): Boolean =
        Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true) ||
            Build.BRAND.equals("Redmi", ignoreCase = true) ||
            Build.BRAND.equals("POCO", ignoreCase = true)

    private fun stateLabel(state: LinkState?): String = when (state) {
        LinkState.CONNECTED -> "已连接"
        LinkState.CONNECTING -> "正在连接…"
        LinkState.WAITING_FOR_COMPUTER -> "等待电脑上线"
        LinkState.REPLACED -> "已在其他地方连接，请重新扫码"
        LinkState.OFFLINE, null -> "未连接"
    }

    private fun heading(text: String, size: Float) {
        content.addView(TextView(this).apply {
            this.text = text
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
    }

    private fun section(text: String) {
        content.addView(TextView(this).apply {
            this.text = text
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, dp(20), 0, dp(6))
        })
    }

    private fun caption(text: String) {
        content.addView(TextView(this).apply {
            this.text = text
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, dp(4), 0, dp(4))
        })
    }

    private fun statusRow(label: String, value: String, ok: Boolean) {
        content.addView(LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(6), 0, dp(6))
            addView(TextView(context).apply {
                text = label
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            })
            addView(TextView(context).apply {
                text = if (ok) "● $value" else "○ $value"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setTextColor(if (ok) 0xFF1B8A4B.toInt() else 0xFFC0392B.toInt())
            })
        })
    }

    private fun button(label: String, action: () -> Unit) {
        content.addView(Button(this).apply {
            text = label
            isAllCaps = false
            setOnClickListener { action() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        })
    }

    private fun toast(text: String) = Toast.makeText(this, text, Toast.LENGTH_LONG).show()

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
