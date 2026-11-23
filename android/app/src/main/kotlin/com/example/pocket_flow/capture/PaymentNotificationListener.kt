package com.example.pocket_flow.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import com.example.pocket_flow.MainActivity
import com.example.pocket_flow.R
import org.json.JSONObject

/**
 * Membaca notifikasi aplikasi pembayaran.
 *
 * Hemat baterai: layanan ini tidak berjalan terus-menerus dan tidak polling.
 * Android hanya memanggil [onNotificationPosted] saat ada notifikasi baru.
 * Di sini kita cuma: (1) cek nama paket ada di daftar, (2) cek teks memuat
 * "Rp", (3) simpan ke antrean lokal. Parsing lengkap dilakukan di Dart saat
 * aplikasi dibuka, sehingga mesin Flutter tidak perlu dinyalakan di background.
 */
class PaymentNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        if (n.packageName == packageName) return
        if (!CaptureStore.allowedPackages(this).contains(n.packageName)) return
        // Ringkasan grup tidak berisi transaksi.
        if (n.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val extras = n.notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        if (!CaptureSources.looksLikeTransaction("$title $text")) return

        val item = JSONObject()
            .put("package", n.packageName)
            .put("app", appLabel(n.packageName))
            .put("title", title.take(200))
            .put("text", text.take(600))
            .put("postedAt", n.postTime)
        CaptureStore.add(this, item)

        // Beri tahu Flutter bila sedang terbuka.
        sendBroadcast(Intent(ACTION_CAPTURED).setPackage(packageName))
        showDetectedNotification(title, text)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        // Minta sistem menyambungkan ulang (mis. setelah layanan dihentikan).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, PaymentNotificationListener::class.java))
        }
    }

    private fun appLabel(pkg: String): String = try {
        val pm = packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: PackageManager.NameNotFoundException) {
        pkg
    }

    /** Notifikasi kecil "Transaksi terdeteksi" + sisa aman hari ini. */
    private fun showDetectedNotification(title: String, text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Transaksi terdeteksi", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Muncul saat PocketFlow membaca transaksi dari aplikasi lain"
                    setShowBadge(true)
                }
            )
        }
        val amount = Regex("""(?i)(rp\.?|idr)\s*[\d.,]+""").find("$title $text")?.value ?: "Transaksi"
        val widget = CaptureStore.widget(this)
        val safe = widget?.optLong("safeToday", -1) ?: -1
        val body = if (safe >= 0) "Ketuk untuk meninjau. Sisa aman hari ini Rp${formatThousands(safe)}."
        else "Ketuk untuk meninjau dan menyimpan."

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = android.net.Uri.parse("pocketflow://app/inbox")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pi = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("$amount terdeteksi")
            .setContentText(body)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        try {
            nm.notify(NOTIF_ID, notif)
        } catch (_: SecurityException) {
            // Izin POST_NOTIFICATIONS belum diberikan (Android 13+): abaikan.
        }
    }

    private fun formatThousands(v: Long): String =
        v.toString().reversed().chunked(3).joinToString(".").reversed()

    companion object {
        const val ACTION_CAPTURED = "com.example.pocket_flow.CAPTURED"
        private const val CHANNEL_ID = "capture_detected"
        private const val NOTIF_ID = 7301
    }
}
