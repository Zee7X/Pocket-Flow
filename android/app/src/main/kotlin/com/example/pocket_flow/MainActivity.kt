package com.example.pocket_flow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.example.pocket_flow.capture.CaptureStore
import com.example.pocket_flow.capture.PaymentNotificationListener
import com.example.pocket_flow.widget.SafeSpendWidget
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketflow/capture").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(isListenerEnabled())
                    "openPermissionSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(null)
                    }
                    "drain" -> result.success(CaptureStore.drain(this@MainActivity))
                    "setAllowedPackages" -> {
                        val list = call.argument<List<String>>("packages") ?: emptyList()
                        CaptureStore.setAllowedPackages(this@MainActivity, list)
                        result.success(null)
                    }
                    "updateWidget" -> {
                        val json = JSONObject()
                            .put("safeToday", (call.argument<Number>("safeToday") ?: 0).toLong())
                            .put("spentToday", (call.argument<Number>("spentToday") ?: 0).toLong())
                            .put("dailyQuota", (call.argument<Number>("dailyQuota") ?: 0).toLong())
                            .put("updatedAt", (call.argument<Number>("updatedAt") ?: 0).toLong())
                        CaptureStore.saveWidget(this@MainActivity, json)
                        SafeSpendWidget.refreshAll(this@MainActivity)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                channel?.invokeMethod("onCaptured", null)
            }
        }
        val filter = IntentFilter(PaymentNotificationListener.ACTION_CAPTURED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(r, filter)
        }
        receiver = r
    }

    override fun onPause() {
        receiver?.let { runCatching { unregisterReceiver(it) } }
        receiver = null
        super.onPause()
    }

    private fun isListenerEnabled(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)

    private fun openBatterySettings() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val intent = if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            // Membuka daftar optimasi baterai (tidak memakai permission
            // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS yang dibatasi Play Store).
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        runCatching { startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            .onFailure {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
    }
}
