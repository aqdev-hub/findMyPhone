package com.findmyphone.find_my_phone

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Bundle
import android.os.Looper
import android.telephony.TelephonyManager
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object DeviceSnapshot {
    fun info(context: Context): String {
        val battery = battery(context)
        val carrier = carrier(context)
        val lastTime = NativeStore.prefs(context).getString("last_location_time", "غير متوفر")
        return "INFO\nBattery: ${battery.first}%\nCharging: ${battery.second}\nCarrier: $carrier\nTime: ${Instant.now()}\nLast location: $lastTime"
    }

    // Short, LOCATE-specific wait for a live fix. Speed matters more than
    // squeezing out a perfect fix here: if nothing arrives in time we fall
    // straight back to the freshest cached position. (The in-app
    // "update location" button and captureFreshLocation use their own,
    // longer timeouts — intentionally untouched.)
    private const val LOCATE_LIVE_TIMEOUT_MS = 12_000L

    // A system-cached fix younger than this is "live enough" to answer
    // immediately instead of waiting for a brand-new fix.
    private const val RECENT_FIX_MAX_AGE_MS = 15_000L

    // Automatic SIM-change alerts run inside a BroadcastReceiver's short
    // goAsync() window, so they use a much shorter location wait.
    private const val ALERT_LIVE_TIMEOUT_MS = 6_000L

    private data class Fix(val source: String, val lat: Any, val lng: Any, val time: String)

    /**
     * Single source of truth for "best location available right now":
     *  1. a very recent system-cached fix (instant),
     *  2. otherwise a live fix (GPS + Network raced, bounded by [liveTimeoutMs]),
     *  3. otherwise the freshest system-cached fix of any age,
     *  4. otherwise our own cached copy from the last app/command capture.
     * Returns null only when nothing at all is known.
     */
    private fun bestFix(context: Context, liveTimeoutMs: Long): Fix? {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)

        // 1. Recent system cache — fastest possible answer.
        for (provider in providers) {
            try {
                val cached = manager.getLastKnownLocation(provider)
                if (cached != null && System.currentTimeMillis() - cached.time <= RECENT_FIX_MAX_AGE_MS) {
                    cacheLocation(context, cached.latitude, cached.longitude)
                    val source = if (provider == LocationManager.GPS_PROVIDER) "GPS" else "Approximate"
                    return Fix(source, cached.latitude, cached.longitude, Instant.ofEpochMilli(cached.time).toString())
                }
            } catch (_: SecurityException) {
            }
        }

        // 2. Live fix, bounded wait.
        val fresh = requestFreshLocationBlocking(context, liveTimeoutMs)
        if (fresh != null) {
            cacheLocation(context, fresh.latitude, fresh.longitude)
            return Fix("GPS (Live)", fresh.latitude, fresh.longitude, Instant.now().toString())
        }

        // 3. Older system cache — better than nothing.
        for (provider in providers) {
            try {
                val location = manager.getLastKnownLocation(provider)
                if (location != null) {
                    val source = if (provider == LocationManager.GPS_PROVIDER) "GPS (Cached)" else "Approximate (Cached)"
                    return Fix(source, location.latitude, location.longitude, Instant.ofEpochMilli(location.time).toString())
                }
            } catch (_: SecurityException) {
            }
        }

        // 4. Our own cache (setup, manual refresh, previous commands).
        val prefs = NativeStore.prefs(context)
        val lat = prefs.getString("last_latitude", null)
        val lng = prefs.getString("last_longitude", null)
        if (lat != null && lng != null) {
            return Fix("Last Known", lat, lng, prefs.getString("last_location_time", "Unavailable") ?: "Unavailable")
        }
        return null
    }

    /** One reply only: the fastest best location available, in the same format as before. */
    fun locate(context: Context): String {
        val fix = bestFix(context, LOCATE_LIVE_TIMEOUT_MS)
            ?: return "LOCATION UNAVAILABLE\nلا يوجد موقع حالي أو آخر موقع محفوظ.\nBattery: ${battery(context).first}%\nCarrier: ${carrier(context)}"
        return locationMessage(context, fix.source, fix.lat, fix.lng, fix.time)
    }

    fun cacheLocation(context: Context, lat: Double, lng: Double) {
        NativeStore.prefs(context).edit()
            .putString("last_latitude", lat.toString())
            .putString("last_longitude", lng.toString())
            .putString("last_location_time", Instant.now().toString())
            .apply()
    }

    /**
     * Blocks the calling (background WorkManager) thread for up to
     * [timeoutMs] waiting for a single fresh location fix. Races GPS and
     * Network providers simultaneously (whichever is enabled) and returns
     * whichever responds first — Network typically wins indoors where GPS
     * struggles to get a lock, GPS typically wins outdoors with a clear
     * sky. Safe to call off the main thread — requestSingleUpdate's
     * callback Looper is independent of the calling thread.
     */
    fun requestFreshLocationBlocking(context: Context, timeoutMs: Long): Location? {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { manager.isProviderEnabled(it) }
        if (providers.isEmpty()) return null

        val latch = CountDownLatch(1)
        var result: Location? = null
        val listeners = mutableMapOf<String, LocationListener>()

        fun cleanup() {
            listeners.values.forEach { l ->
                try { manager.removeUpdates(l) } catch (_: Exception) {}
            }
        }

        return try {
            for (provider in providers) {
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        synchronized(latch) {
                            if (result == null) result = location
                        }
                        latch.countDown()
                    }
                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }
                listeners[provider] = listener
                manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            }
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
            result
        } catch (_: SecurityException) {
            null
        } finally {
            cleanup()
        }
    }

    private fun locationMessage(context: Context, source: String, lat: Any, lng: Any, time: String): String {
        val battery = battery(context).first
        return "LOCATION\nSource: $source\nLat: $lat\nLng: $lng\nUpdated: $time\nBattery: $battery%\nCarrier: ${carrier(context)}\nhttps://maps.google.com/?q=$lat,$lng"
    }

    /** Automatic alert — short, starts with a fixed reason so it can't be mistaken for a command reply. */
    fun simAlert(context: Context): String {
        val fix = bestFix(context, ALERT_LIVE_TIMEOUT_MS)
        val where = if (fix != null) "${fix.lat}, ${fix.lng}\nhttps://maps.google.com/?q=${fix.lat},${fix.lng}" else "الموقع غير متاح / Location unavailable"
        return "تنبيه تلقائي: تغيير شريحة SIM\nAuto alert: SIM changed\nالمشغّل: ${carrier(context)}\n$where"
    }

    private fun carrier(context: Context): String {
        val manager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        return manager.networkOperatorName.takeIf { it.isNotBlank() } ?: "غير متوفر"
    }

    private fun battery(context: Context): Pair<Int, String> {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val percent = if (level >= 0 && scale > 0) (level * 100 / scale) else -1
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        return percent to if (charging) "charging" else "not charging"
    }
}
