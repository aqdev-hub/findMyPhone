package com.findmyphone.find_my_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * SimChangeReceiver also handles BOOT_COMPLETED.
 *
 * NOTE on "reactivation after boot": SmsCommandReceiver (the SMS command
 * entry point) and this receiver are both manifest-registered (static)
 * BroadcastReceivers — Android automatically re-arms these after every
 * reboot with no extra code required, as long as the app hasn't been
 * force-stopped by the user. There is nothing to "re-enable" here. What
 * this receiver adds is the missing piece: a visible audit-log entry
 * confirming the protection service actually came back up, and the
 * existing SIM-change check that already ran on every boot.
 */
class SimChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread {
            try {
                if (!NativeStore.enabled(context)) return@Thread

                if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
                    writeBootLog(context)
                    if (NativeStore.isLiveTrackingActive(context)) {
                        ContextCompat.startForegroundService(
                            context,
                            Intent(context, LiveTrackingService::class.java)
                        )
                        NativeLogChannel.push(
                            "live_track_resumed",
                            "Live tracking resumed after reboot.",
                            Instant.now().toString()
                        )
                    }
                }

                if (NativeStore.simChanged(context)) {
                    val message = DeviceSnapshot.simAlert(context)
                    NativeStore.alertRecipients(context).forEach { phone ->
                        SmsSender.send(context, phone, message)
                    }
                    NativeStore.markCurrentSimAsBaseline(context)
                }
            } finally {
                pending.finish()
            }
        }.start()
    }

    private fun writeBootLog(context: Context) {
        val timestamp = Instant.now().toString()
        try {
            val prefs = NativeStore.prefs(context)
            val existing = prefs.getString(NativeStore.PENDING_LOGS_KEY, "[]") ?: "[]"
            val array = JSONArray(existing)
            array.put(
                JSONObject().apply {
                    put("type", "device_boot")
                    put("message", "Device restarted — protection service is active.")
                    put("timestamp", timestamp)
                }
            )
            prefs.edit().putString(NativeStore.PENDING_LOGS_KEY, array.toString()).apply()
        } catch (_: Exception) {
            // Never crash the receiver due to logging failure
        }
        NativeLogChannel.push("device_boot", "Device restarted — protection service is active.", timestamp)
    }
}
