package com.findmyphone.find_my_phone

import android.content.Context
import android.content.Intent
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * SimWorker — handles SIM state change and boot events in the background.
 *
 * On BOOT_COMPLETED: re-syncs the security state (NativeStore remains valid
 * since EncryptedSharedPreferences persists across reboots, but WorkManager
 * and in-memory state need no reset — this is a no-op confirmation).
 *
 * On SIM_STATE_CHANGED / related events: compares current SIM fingerprint
 * against stored baseline. If changed, sends alert SMS to all alert recipients
 * and updates the baseline.
 */
class SimWorker(
    private val context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        const val TAG = "sim_worker"
        const val KEY_ACTION = "action"
        private const val PENDING_LOGS_KEY = "pending_native_logs"
    }

    override fun doWork(): Result {
        return try {
            val action = inputData.getString(KEY_ACTION) ?: return Result.success()
            when (action) {
                Intent.ACTION_BOOT_COMPLETED,
                "android.intent.action.LOCKED_BOOT_COMPLETED" -> handleBoot()

                "android.intent.action.SIM_STATE_CHANGED",
                "android.telephony.action.MULTI_SIM_CONFIG_CHANGED",
                "android.telephony.action.SUBSCRIPTION_CARRIER_IDENTITY_CHANGED" -> handleSimChange()
            }
            Result.success()
        } catch (e: Exception) {
            writeLog("sim_error", "SimWorker exception: ${e.message}")
            Result.failure()
        }
    }

    private fun handleBoot() {
        writeLog("boot", "Device booted. SMS protection active.")
        // No additional action needed — NativeStore persists across reboots.
        // WorkManager itself re-registers after boot automatically.
    }

    private fun handleSimChange() {
        if (!NativeStore.simChanged(context)) {
            // SIM_STATE_CHANGED fires frequently (airplane mode, screen lock, etc.)
            // Only act when the fingerprint actually differs from the stored baseline.
            return
        }

        writeLog("sim_change", "SIM change detected. Sending alerts.")

        val message = DeviceSnapshot.simAlert(context)
        val recipients = NativeStore.alertRecipients(context)

        if (recipients.isEmpty()) {
            writeLog("sim_change", "No alert recipients configured.")
            return
        }

        for (phone in recipients) {
            try {
                SmsSender.send(context, phone, message)
                writeLog("sim_change", "SIM alert sent to $phone")
            } catch (e: Exception) {
                writeLog("sim_error", "Failed to send SIM alert to $phone: ${e.message}")
            }
        }

        // Update baseline AFTER sending alerts
        NativeStore.markCurrentSimAsBaseline(context)
        writeLog("sim_change", "SIM baseline updated.")
    }

    private fun writeLog(type: String, message: String) {
        try {
            val prefs = NativeStore.prefs(context)
            val existing = prefs.getString(PENDING_LOGS_KEY, "[]") ?: "[]"
            val array = JSONArray(existing)
            array.put(
                JSONObject().apply {
                    put("type", type)
                    put("message", message)
                    put("timestamp", Instant.now().toString())
                }
            )
            val capped = if (array.length() > 500) {
                val trimmed = JSONArray()
                for (i in (array.length() - 500) until array.length()) {
                    trimmed.put(array.getJSONObject(i))
                }
                trimmed
            } else array
            prefs.edit().putString(PENDING_LOGS_KEY, capped.toString()).apply()
        } catch (_: Exception) {}
    }
}
