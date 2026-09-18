package com.findmyphone.find_my_phone

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * ProtectionDeviceAdminReceiver — anti-uninstall protection.
 *
 * While this app is an active Device Admin, Android blocks uninstalling it
 * directly; the user must first visit Settings → Security → Device admin
 * apps → deactivate. This receiver:
 *   - onDisableRequested(): supplies the strong warning text shown on that
 *     exact system confirmation screen.
 *   - onDisabled(): fires the instant it's actually deactivated — logs the
 *     event and alerts every trusted contact by SMS, since a legitimate
 *     owner would normally do this from a place of safety, not urgency.
 *
 * See DeviceAdminUtil for what this protection can and cannot guarantee.
 */
class ProtectionDeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        writeLog(context, "device_admin", "Anti-uninstall protection activated.")
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        // Shown by the OS on the built-in "Deactivate device admin?" screen,
        // right before the user confirms. This is the only customization
        // point Android gives a normal app on that screen.
        return "تحذير: إلغاء تفعيل هذه الحماية يسمح بإلغاء تثبيت التطبيق ويوقف حماية السرقة عن هذا الهاتف. " +
            "إذا لم يكن هذا هاتفك، الرجاء إعادته لصاحبه فورًا.\n\n" +
            "Warning: disabling this removes theft protection and allows uninstalling the app. " +
            "If this isn't your phone, please return it to its owner immediately."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        writeLog(context, "device_admin_disabled", "Anti-uninstall protection was deactivated on this device.")

        // Only alert if protection was actually turned on (contacts + code
        // configured) — otherwise this fires harmlessly for users who enabled
        // then disabled admin during setup before finishing configuration.
        if (!NativeStore.enabled(context)) return

        val recipients = NativeStore.alertRecipients(context)
        if (recipients.isEmpty()) return

        val message = "تنبيه أمني: تم إلغاء تفعيل حماية إلغاء التثبيت على هاتفك.\n" +
            "SECURITY ALERT: Anti-uninstall protection was just deactivated on your phone.\n" +
            "Time: ${Instant.now()}"

        for (phone in recipients) {
            try {
                SmsSender.send(context, phone, message)
                writeLog(context, "device_admin_disabled", "Alert sent to $phone")
            } catch (e: Exception) {
                writeLog(context, "device_admin_error", "Failed to alert $phone: ${e.message}")
            }
        }
    }

    /**
     * Writes to the same "pending_native_logs" store used by SmsProcessorWorker
     * and SimWorker, so this event shows up in the app's Security Log the next
     * time it's opened (or immediately, via NativeLogChannel, if it's already
     * running).
     */
    private fun writeLog(context: Context, type: String, message: String) {
        val timestamp = Instant.now().toString()
        try {
            val prefs = NativeStore.prefs(context)
            val existing = prefs.getString(NativeStore.PENDING_LOGS_KEY, "[]") ?: "[]"
            val array = JSONArray(existing)
            array.put(
                JSONObject().apply {
                    put("type", type)
                    put("message", message)
                    put("timestamp", timestamp)
                }
            )
            val capped = if (array.length() > 500) {
                val trimmed = JSONArray()
                for (i in (array.length() - 500) until array.length()) {
                    trimmed.put(array.getJSONObject(i))
                }
                trimmed
            } else {
                array
            }
            prefs.edit().putString(NativeStore.PENDING_LOGS_KEY, capped.toString()).apply()
        } catch (_: Exception) {
            // Never crash the receiver due to logging failure
        }
        NativeLogChannel.push(type, message, timestamp)
    }
}
