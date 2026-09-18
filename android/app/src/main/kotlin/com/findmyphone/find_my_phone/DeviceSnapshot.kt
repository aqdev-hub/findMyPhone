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

    fun locate(context: Context): String {
        // 1. ALWAYS get a fresh, live fix first — this is the entire point
        // of a LOCATE command: the owner wants to know where the phone is
        // RIGHT NOW, not wherever it happened to be the last time someone
        // opened the app or ran a previous command. Bounded wait so a
        // no-signal environment still degrades gracefully to cached data
        // below instead of hanging.
        val fresh = requestFreshLocationBlocking(context, timeoutMs = 15_000)
        if (fresh != null) {
            cacheLocation(context, fresh.latitude, fresh.longitude)
            return locationMessage(context, "GPS (Live)", fresh.latitude, fresh.longitude, Instant.now().toString())
        }

        // 2. Fresh fix failed or timed out (e.g. deep indoors, airplane
        // mode) — fall back to whatever the system has cached.
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        for (provider in providers) {
            try {
                val location = manager.getLastKnownLocation(provider)
                if (location != null) {
                    val source = if (provider == LocationManager.GPS_PROVIDER) "GPS (Cached)" else "Approximate (Cached)"
                    return locationMessage(context, source, location.latitude, location.longitude, Instant.ofEpochMilli(location.time).toString())
                }
            } catch (_: SecurityException) {
            }
        }

        // 3. Our own cache, populated whenever the Flutter side last
        // captured a fix (setup, manual refresh, or a previous command).
        val prefs = NativeStore.prefs(context)
        val lat = prefs.getString("last_latitude", null)
        val lng = prefs.getString("last_longitude", null)
        val time = prefs.getString("last_location_time", "Unavailable") ?: "Unavailable"
        if (lat != null && lng != null) return locationMessage(context, "Last Known", lat, lng, time)

        return "LOCATION UNAVAILABLE\nلا يوجد موقع حالي أو آخر موقع محفوظ.\nBattery: ${battery(context).first}%\nCarrier: ${carrier(context)}"
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

    fun simAlert(context: Context): String {
        val last = locate(context)
        return "SIM CHANGE ALERT\nTime: ${Instant.now()}\nCarrier: ${carrier(context)}\n$last"
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
