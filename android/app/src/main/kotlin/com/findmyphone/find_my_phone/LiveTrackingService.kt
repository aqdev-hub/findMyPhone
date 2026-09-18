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
import java.time.Instant

/**
 * LiveTrackingService — "تتبع_مباشر" / LIVETRACK.
 *
 * Design (deliberately server-free, matching the rest of this app): rather
 * than depending on a backend + live web map (which would require hosting,
 * an internet connection on both ends, and a recurring cost the developer
 * would have to carry), this periodically sends a fresh SMS with the
 * current position and a Google Maps link to whoever activated tracking.
 * Each message is a new "frame"; opening several in sequence in the SMS
 * thread shows the phone's movement over time, entirely over plain SMS —
 * no data connection required on the tracked phone, no server anywhere.
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

    companion object {
        // Minimum time AND distance between SMS updates — avoids spamming
        // the trusted contact (and burning SMS) on every tiny GPS jitter,
        // while still feeling genuinely "live" for tracking a moving phone.
        private const val MIN_INTERVAL_MS = 90_000L // 90 seconds
        private const val MIN_DISTANCE_M = 60f
        private const val MIN_TIME_BETWEEN_UPDATES_MS = 60_000L
        private const val MIN_DISTANCE_BETWEEN_UPDATES_M = 30f
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
                    MIN_TIME_BETWEEN_UPDATES_MS,
                    MIN_DISTANCE_BETWEEN_UPDATES_M,
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
        val movedEnough = lastSentLocation?.distanceTo(location)?.let { it >= MIN_DISTANCE_M } ?: true
        val enoughTimePassed = now - lastSentAt >= MIN_INTERVAL_MS
        if (!movedEnough && !enoughTimePassed) return

        lastSentAt = now
        lastSentLocation = location
        DeviceSnapshot.cacheLocation(applicationContext, location.latitude, location.longitude)

        val requester = NativeStore.liveTrackingRequester(applicationContext) ?: return
        val model = Build.MODEL ?: "الجهاز"
        val message = "تتبع مباشر: $model\n" +
            "${location.latitude}, ${location.longitude}\n" +
            "https://maps.google.com/?q=${location.latitude},${location.longitude}"
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
