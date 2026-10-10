package com.findmyphone.find_my_phone

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * LiveTrackingService — "تتبع_مباشر" / LIVETRACK.
 *
 * Design (deliberately server-free, matching the rest of this app): no
 * backend and no live web map. Once activated, the first fix is sent to the
 * requester immediately, and from then on a NEW SMS (device name, precise
 * coordinates, Google Maps link) is sent each time the phone has moved
 * 100 m from the last position that was sent. Opening the messages in order
 * shows the phone's movement over time, entirely over plain SMS.
 *
 * Differs from LOCATE on purpose: LOCATE answers once, instantly; LIVETRACK
 * stays on and keeps reporting movement.
 *
 * Stays active — including across reboots — until the phone's own user
 * opens the app and explicitly stops it. It is NOT stoppable via SMS by
 * design: once a trusted contact has activated tracking on what may be a
 * stolen phone, a thief must not be able to turn it back off remotely.
 */
class LiveTrackingService : Service() {
    private var locationManager: LocationManager? = null
    private val listeners = mutableListOf<LocationListener>()
    private var lastSentAt: Long = 0
    private var lastSentLocation: Location? = null
    private var lastGpsFixAt: Long = 0

    companion object {
        // Primary trigger: a new SMS goes out only when the phone has moved
        // at least this far from the LAST POSITION WE SENT (not from the
        // last fix received), so slow drift can't spam the trusted contact.
        private const val MIN_SEND_DISTANCE_M = 100f

        // Symbolic safety floor only (guards against a glitchy burst of
        // fixes) — deliberately NOT the main throttle any more.
        private const val MIN_SEND_INTERVAL_MS = 15_000L

        // Ask the OS for frequent, fine-grained updates: for this feature
        // accuracy matters more than battery.
        private const val UPDATE_MIN_TIME_MS = 5_000L
        private const val UPDATE_MIN_DISTANCE_M = 10f

        // GPS and Network run side by side (a "race" for each update).
        // A Network fix is only used when GPS hasn't produced one recently
        // (e.g. indoors) — otherwise its much coarser accuracy would cause
        // false "moved 100 m" messages and imprecise positions.
        private const val GPS_PREFERENCE_WINDOW_MS = 45_000L

        // A fix's own uncertainty radius, capped, so a very coarse fix
        // can't make tracking go completely silent.
        private const val MAX_ACCURACY_GUARD_M = 300f

        const val NOTIFICATION_ID = 202
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        startLocationUpdates()
        return START_STICKY
    }

    override fun onDestroy() {
        stopLocationUpdates()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startLocationUpdates() {
        stopLocationUpdates()
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        locationManager = manager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { manager.isProviderEnabled(it) }

        for (provider in providers) {
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) = onFix(location)
                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }
            try {
                manager.requestLocationUpdates(
                    provider,
                    UPDATE_MIN_TIME_MS,
                    UPDATE_MIN_DISTANCE_M,
                    listener,
                    Looper.getMainLooper()
                )
                listeners.add(listener)
            } catch (_: SecurityException) {
                // Permission revoked mid-tracking — nothing more we can do
                // for this provider; the other one (if any) may still work.
            }
        }
    }

    private fun stopLocationUpdates() {
        val manager = locationManager ?: return
        listeners.forEach { l ->
            try { manager.removeUpdates(l) } catch (_: Exception) {}
        }
        listeners.clear()
    }

    private fun onFix(location: Location) {
        val now = System.currentTimeMillis()

        // Prefer GPS; accept a Network fix only when GPS has been silent.
        if (location.provider == LocationManager.GPS_PROVIDER) {
            lastGpsFixAt = now
        } else if (now - lastGpsFixAt < GPS_PREFERENCE_WINDOW_MS) {
            return
        }

        val previous = lastSentLocation
        if (previous != null) {
            if (now - lastSentAt < MIN_SEND_INTERVAL_MS) return
            // Movement must exceed 100 m AND the fix's own uncertainty
            // (capped) — otherwise it's just noise, not real movement.
            val required = maxOf(
                MIN_SEND_DISTANCE_M,
                if (location.hasAccuracy()) minOf(location.accuracy, MAX_ACCURACY_GUARD_M) else 0f
            )
            if (previous.distanceTo(location) < required) return
        }
        // (No previous position = first fix after activation/resume → send
        // immediately so the requester gets the current location at once.)

        lastSentAt = now
        lastSentLocation = location
        DeviceSnapshot.cacheLocation(applicationContext, location.latitude, location.longitude)

        val requester = NativeStore.liveTrackingRequester(applicationContext) ?: return
        val model = Build.MODEL ?: "الجهاز"
        val lat = String.format(java.util.Locale.US, "%.6f", location.latitude)
        val lng = String.format(java.util.Locale.US, "%.6f", location.longitude)
        val message = "تتبع مباشر: $model\n" +
            "$lat, $lng\n" +
            "https://maps.google.com/?q=$lat,$lng"
        try {
            SmsSender.send(applicationContext, requester, message)
        } catch (_: Exception) {
            // Best-effort — a single failed SMS shouldn't stop tracking.
        }
    }

    private fun buildNotification() =
        NotificationCompat.Builder(this, "live_tracking")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("التتبع المباشر نشط")
            .setContentText("افتح التطبيق لإيقاف التتبع المباشر.")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(
                PendingIntent.getActivity(
                    this, 20,
                    packageManager.getLaunchIntentForPackage(packageName),
                    PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "live_tracking", "Live tracking", NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
