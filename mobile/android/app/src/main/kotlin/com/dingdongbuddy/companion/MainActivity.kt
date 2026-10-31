package com.dingdongbuddy.companion

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter UI and the few Android-only calls Dart cannot make
 * itself: QR scanning, Downloads, HyperOS settings shortcuts and launch links.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingLaunchText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingLaunchText = launchText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = launchText(intent) ?: return
        val current = channel
        if (current == null) {
            pendingLaunchText = text
        } else {
            current.invokeMethod("launchText", text)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dingdong/native").apply {
            setMethodCallHandler(::handle)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeLaunchText" -> {
                result.success(pendingLaunchText)
                pendingLaunchText = null
            }
            "scanQr" -> scanQr(result)
            "deviceName" -> result.success(deviceName())
            "isXiaomi" -> result.success(
                Build.MANUFACTURER.equals("Xiaomi", true) ||
                    Build.BRAND.equals("Redmi", true) ||
                    Build.BRAND.equals("POCO", true),
            )
            "notificationsEnabled" -> result.success(
                getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
            )
            "isIgnoringBatteryOptimizations" -> result.success(
                getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName),
            )
            "requestBatteryExemption" -> result.success(
                start(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))),
            )
            "openNotificationSettings" -> result.success(
                start(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)),
            )
            "openAppDetails" -> result.success(openAppDetails())
            "openAutostart" -> result.success(
                start(
                    Intent().setComponent(
                        ComponentName(
                            "com.miui.securitycenter",
                            "com.miui.permcenter.autostart.AutoStartManagementActivity",
                        ),
                    ),
                ) || openAppDetails(),
            )
            "saveToDownloads" -> saveToDownloads(call, result)
            else -> result.notImplemented()
        }
    }

    private fun launchText(intent: Intent?): String? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.dataString
        Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
        else -> null
    }?.takeIf { it.contains("#pair=") }

    private fun scanQr(result: MethodChannel.Result) {
        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        GmsBarcodeScanning.getClient(this, options).startScan()
            .addOnSuccessListener { result.success(it.rawValue) }
            .addOnCanceledListener { result.success(null) }
            .addOnFailureListener { result.error("scan_failed", it.message, null) }
    }

    /** Copies a finished download into the public Downloads collection. */
    private fun saveToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val name = call.argument<String>("name")
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        if (path == null || name == null) {
            result.error("bad_args", "path and name are required", null)
            return
        }
        try {
            val source = File(path)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(MediaStore.Downloads.MIME_TYPE, mime)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("MediaStore refused the download")
                contentResolver.openOutputStream(uri).use { output ->
                    source.inputStream().use { it.copyTo(output!!) }
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                result.success("${Environment.DIRECTORY_DOWNLOADS}/$name")
            } else {
                // Android 8–9 would need storage permission for public
                // Downloads; keep the file in the app's own download folder.
                val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: throw IllegalStateException("No external files directory")
                source.copyTo(File(directory, name), overwrite = true)
                result.success(File(directory, name).path)
            }
        } catch (error: Exception) {
            result.error("save_failed", error.message, null)
        }
    }

    private fun deviceName(): String {
        val configured = Settings.Global.getString(contentResolver, "device_name")
        if (!configured.isNullOrBlank()) return configured.trim().take(32)
        val model = Build.MODEL.orEmpty()
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val name = if (model.startsWith(manufacturer, ignoreCase = true)) model else "$manufacturer $model"
        return name.trim().ifEmpty { "Android 手机" }.take(32)
    }

    private fun openAppDetails(): Boolean =
        start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))

    private fun start(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }
}
