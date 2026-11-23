package com.example.pocket_flow.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.pocket_flow.MainActivity
import com.example.pocket_flow.R
import com.example.pocket_flow.capture.CaptureStore

/**
 * Widget layar utama "Sisa aman hari ini". Datanya dikirim Flutter setiap
 * kali dashboard dihitung ulang (CaptureChannel.updateWidget), jadi widget
 * tidak perlu jaringan atau proses background sendiri.
 */
class SafeSpendWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, buildViews(context))
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SafeSpendWidget::class.java))
            if (ids.isEmpty()) return
            val views = buildViews(context)
            for (id in ids) manager.updateAppWidget(id, views)
        }

        private fun rp(v: Long): String =
            "Rp" + v.toString().reversed().chunked(3).joinToString(".").reversed()

        private fun buildViews(context: Context): RemoteViews {
            val data = CaptureStore.widget(context)
            val views = RemoteViews(context.packageName, R.layout.widget_safe_spend)
            if (data == null) {
                views.setTextViewText(R.id.widget_amount, "—")
                views.setTextViewText(R.id.widget_sub, "Buka PocketFlow untuk memuat data")
            } else {
                val safe = data.optLong("safeToday")
                val spent = data.optLong("spentToday")
                val quota = data.optLong("dailyQuota")
                views.setTextViewText(R.id.widget_amount, rp(safe))
                views.setTextViewText(
                    R.id.widget_sub,
                    if (quota > 0) "Terpakai ${rp(spent)} dari ${rp(quota)}" else "Terpakai ${rp(spent)} hari ini",
                )
            }
            val open = PendingIntent.getActivity(
                context, 1,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            return views
        }
    }
}
