package com.example.pocket_flow.capture

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Antrean notifikasi yang tertangkap, disimpan di SharedPreferences privat
 * aplikasi. Isinya hanya hidup di perangkat dan dihapus begitu Flutter
 * membacanya (drain). Maksimal [MAX_ITEMS] item supaya tidak membengkak
 * bila aplikasi lama tidak dibuka.
 */
object CaptureStore {
    private const val PREFS = "pocketflow_capture"
    private const val KEY_QUEUE = "queue"
    private const val KEY_ALLOWED = "allowed_packages"
    private const val KEY_WIDGET = "widget"
    private const val MAX_ITEMS = 300

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun add(ctx: Context, item: JSONObject) {
        val p = prefs(ctx)
        val arr = JSONArray(p.getString(KEY_QUEUE, "[]"))
        // Notifikasi yang sama bisa diposting ulang (update). Lewati duplikat persis.
        val sig = item.optString("package") + "|" + item.optString("title") + "|" + item.optString("text")
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val s = o.optString("package") + "|" + o.optString("title") + "|" + o.optString("text")
            if (s == sig && kotlin.math.abs(o.optLong("postedAt") - item.optLong("postedAt")) < 120_000) return
        }
        arr.put(item)
        val trimmed = if (arr.length() > MAX_ITEMS) {
            val out = JSONArray()
            for (i in arr.length() - MAX_ITEMS until arr.length()) out.put(arr.get(i))
            out
        } else arr
        p.edit().putString(KEY_QUEUE, trimmed.toString()).apply()
    }

    @Synchronized
    fun drain(ctx: Context): List<Map<String, Any?>> {
        val p = prefs(ctx)
        val arr = JSONArray(p.getString(KEY_QUEUE, "[]"))
        p.edit().putString(KEY_QUEUE, "[]").apply()
        val out = ArrayList<Map<String, Any?>>(arr.length())
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            out.add(
                mapOf(
                    "package" to o.optString("package"),
                    "app" to o.optString("app"),
                    "title" to o.optString("title"),
                    "text" to o.optString("text"),
                    "postedAt" to o.optLong("postedAt"),
                )
            )
        }
        return out
    }

    fun setAllowedPackages(ctx: Context, packages: List<String>) {
        prefs(ctx).edit().putStringSet(KEY_ALLOWED, packages.toSet()).apply()
    }

    /** Null = belum pernah diatur dari Flutter: pakai daftar bawaan. */
    fun allowedPackages(ctx: Context): Set<String> =
        prefs(ctx).getStringSet(KEY_ALLOWED, null) ?: CaptureSources.DEFAULT_PACKAGES

    fun saveWidget(ctx: Context, json: JSONObject) {
        prefs(ctx).edit().putString(KEY_WIDGET, json.toString()).apply()
    }

    fun widget(ctx: Context): JSONObject? =
        prefs(ctx).getString(KEY_WIDGET, null)?.let { runCatching { JSONObject(it) }.getOrNull() }
}
