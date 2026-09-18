package com.findmyphone.find_my_phone

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * SmsProcessorWorker — processes an incoming SMS command in the background.
 *
 * This Worker:
 *   1. Verifies the sender is a trusted contact.
 *   2. Verifies the emergency code hash (120,000-round SHA-256).
 *   3. Dispatches the appropriate action (LOCATE / SILENTLOCATE / INFO / ALARM / LOCK / RESET).
 *   4. Sends an SMS reply when possible.
 *   5. Writes an audit log entry to EncryptedSharedPreferences.
 *      (SQLCipher is Flutter-only; from native we use EncryptedSharedPreferences
 *       as the audit log store, and Flutter reads them via getPendingNativeLogs()
 *       on next app open, then writes them into SQLCipher and clears the prefs.)
 *
 * ANDROID LIMITATION — Location from Worker:
 *   A Worker runs in the background. On Android 10+ getting a *fresh* GPS fix from
 *   background requires ACCESS_BACKGROUND_LOCATION AND the app being in the
 *   "Allow all the time" location mode. We therefore use getLastKnownLocation()
 *   (cached by the OS) which does NOT require a fresh foreground fix.
 *   If no cached location exists we return the last location saved by the Flutter
 *   app via NativeStore.saveLastKnownLocation().
 *
 * ANDROID LIMITATION — ForegroundService from Worker (Android 12+):
 *   We start AlarmForegroundService via ContextCompat.startForegroundService().
 *   On Android 12+, background-started foreground services are restricted unless
 *   the app has FOREGROUND_SERVICE_SPECIAL_USE declared. We have declared it.
 */
class SmsProcessorWorker(
    private val context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        const val TAG = "sms_processor"
        const val KEY_SENDER = "sender"
        const val KEY_BODY = "body"

        // Maps both English and Arabic command keywords to the canonical
        // (English) command name used internally. Arabic senders can use
        // either the Arabic word or the English one — both work identically.
        private val COMMAND_ALIASES: Map<String, String> = mapOf(
            "LOCATE" to "LOCATE",
            "موقع" to "LOCATE",
            "تحديد_الموقع" to "LOCATE",

            "SILENTLOCATE" to "SILENTLOCATE",
            "موقع_صامت" to "SILENTLOCATE",
            "تتبع_صامت" to "SILENTLOCATE",

            "ALARM" to "ALARM",
            "انذار" to "ALARM",
            "إنذار" to "ALARM",

            "INFO" to "INFO",
            "معلومات" to "INFO",

            "LOCK" to "LOCK",
            "قفل" to "LOCK",
            "قفل_الجهاز" to "LOCK",

            "RESET" to "RESET",
            "استرجاع" to "RESET",
            "إعادة_تعيين" to "RESET",
            "اعادة_تعيين" to "RESET",

            "LIVETRACK" to "LIVETRACK",
            "تتبع_مباشر" to "LIVETRACK",
        )

        /**
         * Normalizes a raw command token (Arabic or English, any case) into the
         * canonical English command name, or null if unrecognized.
         */
        fun normalizeCommand(raw: String): String? {
            val cleaned = raw.trim().uppercase()
            return COMMAND_ALIASES[cleaned]
        }
    }

    override fun doWork(): Result {
        val sender = inputData.getString(KEY_SENDER).orEmpty()
        val body = inputData.getString(KEY_BODY).orEmpty()

        return try {
            process(sender, body)
            Result.success()
        } catch (e: Exception) {
            writeLog("error", "Worker exception for sender=$sender — ${e.message}")
            Result.failure()
        }
    }

    private fun process(sender: String, body: String) {
        // ── Step 1: Parse command ───────────────────────────────────────────
        val parts = body.trim().split(Regex("\\s+"))
        if (parts.size != 2) {
            writeLog("sms_ignored", "Message from $sender ignored — not a 2-part command.")
            return
        }
        val rawCommand = parts[0]
        val code = parts[1]
        val command = normalizeCommand(rawCommand)

        if (command == null) {
            writeLog("sms_ignored", "Unknown command '$rawCommand' from $sender.")
            return
        }

        // ── Step 2: Verify sender is a pre-registered trusted contact ───────
        if (!NativeStore.isTrusted(context, sender)) {
            writeLog("sms_rejected", "Untrusted sender: $sender — command: $command")
            // Do NOT reply to untrusted senders (prevents enumeration)
            return
        }

        // ── Step 3: Brute-force lockout check ────────────────────────────────
        // Applies to every command except RESET itself, so a locked-out
        // sender can still recover their code once the window expires, but
        // can't use repeated guesses to brute-force the emergency code.
        if (command != "RESET" && NativeStore.isLockedOut(context)) {
            writeLog("sms_locked_out", "Command $command from $sender rejected — too many recent failed attempts.")
            SmsSender.send(
                context,
                sender,
                "تم إيقاف الأوامر مؤقتًا بسبب محاولات فاشلة متكررة. حاول لاحقًا.\n" +
                    "Commands temporarily locked due to repeated failed attempts. Try again later."
            )
            return
        }

        // ── Step 4: RESET is special — no old code required by design ───────
        // Trust is anchored on the sender being pre-registered (Step 2) since
        // the entire point of RESET is recovering from a forgotten code.
        if (command == "RESET") {
            handleReset(sender, code)
            return
        }

        // ── Step 5: Verify emergency code for every other command ───────────
        val salt = NativeStore.codeSalt(context)
        val hash = NativeStore.codeHash(context)

        if (salt.isBlank() || hash.isBlank()) {
            writeLog("sms_error", "No code configured. Setup not complete.")
            SmsSender.send(context, sender, "خطأ: لم يكتمل الإعداد.\nError: setup not complete.")
            return
        }

        if (!Security.verify(code, salt, hash)) {
            val attempts = NativeStore.recordFailedAttempt(context)
            writeLog("sms_rejected", "Invalid code from trusted sender $sender — command: $command (attempt $attempts)")
            SmsSender.send(context, sender, "مرفوض: رمز الطوارئ غير صحيح.\nRejected: invalid emergency code.")
            if (NativeStore.isLockedOut(context)) {
                val alertMsg = "تنبيه أمني: تم إيقاف أوامر SMS مؤقتًا بعد عدة محاولات رمز فاشلة.\n" +
                    "SECURITY ALERT: SMS commands were temporarily locked after repeated failed code attempts."
                NativeStore.alertRecipients(context).forEach { phone ->
                    SmsSender.send(context, phone, alertMsg)
                }
                writeLog("lockout_triggered", "Lockout triggered by repeated failures from $sender; all trusted contacts alerted.")
            }
            return
        }
        NativeStore.resetFailedAttempts(context)

        // ── Step 6: Execute command ─────────────────────────────────────────
        writeLog("sms_accepted", "Command $command accepted from $sender")

        when (command) {
            "LOCATE" -> {
                val reply = DeviceSnapshot.locate(context)
                SmsSender.send(context, sender, reply)
                writeLog("locate", "Location sent to $sender")
            }

            "SILENTLOCATE" -> {
                // Silent: reply with location but do NOT start alarm or show UI
                val reply = DeviceSnapshot.locate(context)
                SmsSender.send(context, sender, reply)
                writeLog("silentlocate", "Silent location sent to $sender")
            }

            "INFO" -> {
                val reply = DeviceSnapshot.info(context)
                SmsSender.send(context, sender, reply)
                writeLog("info", "Device info sent to $sender")
            }

            "ALARM" -> {
                // Start the foreground alarm service
                val alarmIntent = Intent(context, AlarmForegroundService::class.java)
               // alarmIntent.action = AlarmForegroundService.ACTION_START
                ContextCompat.startForegroundService(context, alarmIntent)
                SmsSender.send(
                    context,
                    sender,
                    "تم تشغيل الإنذار\nالوقت: ${Instant.now()}"
                )
                writeLog("alarm", "Alarm started — triggered by $sender")
            }

            "LOCK" -> {
                if (DeviceAdminUtil.lockNow(context)) {
                    SmsSender.send(context, sender, "تم قفل الجهاز.\nDevice locked.\nالوقت: ${Instant.now()}")
                    writeLog("lock", "Device locked — triggered by $sender")
                } else {
                    // Honest failure: device admin must be activated in-app
                    // first (Settings → Anti-Uninstall Protection). Silently
                    // ignoring this would leave the sender believing the
                    // phone is locked when it isn't.
                    SmsSender.send(
                        context,
                        sender,
                        "تعذّر القفل: فعّل \"الحماية من إلغاء التثبيت\" من إعدادات التطبيق أولًا.\n" +
                            "Lock failed: activate \"Anti-Uninstall Protection\" in the app's settings first."
                    )
                    writeLog("lock_failed", "LOCK requested by $sender but device admin is not active.")
                }
            }

            "LIVETRACK" -> {
                if (NativeStore.isLiveTrackingActive(context)) {
                    SmsSender.send(
                        context,
                        sender,
                        "التتبع المباشر مُفعَّل بالفعل.\nLive tracking is already active."
                    )
                } else {
                    NativeStore.setLiveTrackingActive(context, true, sender)
                    val intent = Intent(context, LiveTrackingService::class.java)
                    ContextCompat.startForegroundService(context, intent)
                    val model = android.os.Build.MODEL ?: "الجهاز"
                    SmsSender.send(
                        context,
                        sender,
                        "تم تفعيل التتبع المباشر لهاتف $model.\n" +
                            "ستصلك تحديثات دورية للموقع حتى يوقفها صاحب الهاتف من داخل التطبيق.\n" +
                            "Live tracking activated. You'll get periodic location updates until the owner stops it from the app."
                    )
                    writeLog("live_track_started", "Live tracking activated by $sender")
                }
            }
        }
    }

    /**
     * RESET/استرجاع <newcode> — lets a pre-registered trusted contact set a
     * brand-new emergency code without knowing the old one. Every OTHER
     * trusted contact is alerted immediately so an unexpected reset never
     * goes unnoticed by the phone's owner.
     */
    private fun handleReset(sender: String, newCode: String) {
        if (!Security.isValidFormat(newCode)) {
            SmsSender.send(
                context,
                sender,
                "رمز غير صالح: يجب أن يكون 6-12 حرفًا/رقمًا إنجليزيًا.\n" +
                    "Invalid code: must be 6-12 English letters/digits."
            )
            writeLog("reset_rejected", "RESET from $sender rejected — invalid new-code format.")
            return
        }

        val salt = Security.generateSalt()
        val hash = Security.hash(newCode, salt)
        NativeStore.setCode(context, salt, hash)
        NativeStore.resetFailedAttempts(context)

        SmsSender.send(
            context,
            sender,
            "تم تعيين رمز طوارئ جديد بنجاح.\n" +
                "New emergency code set successfully."
        )
        writeLog("code_reset", "Emergency code reset by trusted contact $sender")

        // Notify every OTHER trusted contact — an unexpected reset should
        // never go unnoticed by the device owner.
        val alertMsg = "تنبيه: تم تغيير رمز الطوارئ بواسطة رقم موثوق (${sender}). إن لم يكن هذا بطلب منك، تواصل فورًا.\n" +
            "ALERT: the emergency code was just reset by trusted number ($sender). If this wasn't you, act immediately."
        NativeStore.alertRecipients(context)
            .filter { NativeStore.normalizePhone(it) != NativeStore.normalizePhone(sender) }
            .forEach { phone -> SmsSender.send(context, phone, alertMsg) }
    }

    /**
     * Writes an audit log entry to EncryptedSharedPreferences.
     *
     * WHY NOT SQLCipher:
     * SQLCipher is accessed exclusively through the Flutter sqflite_sqlcipher plugin.
     * From a native Worker (no Flutter Engine running), there is no Dart isolate to
     * call into. Writing directly to the SQLCipher file from Kotlin would require
     * linking the native SQLCipher .so separately, which is not declared in this build.
     *
     * SOLUTION: We accumulate log entries as a JSON array in EncryptedSharedPreferences
     * under the key "pending_native_logs". When the Flutter app opens, MainActivity
     * returns these logs via getPendingNativeLogs(), the Dart layer inserts them into
     * SQLCipher, and then calls clearPendingNativeLogs() to remove them from prefs.
     */
    private fun writeLog(type: String, message: String) {
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
            // Cap at 500 entries to prevent unbounded growth if app is never opened
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
            // Never crash the worker due to logging failure
        }
        // Also push in real time in case the Flutter engine happens to be alive
        // (e.g. app is in the foreground/background but not killed). No-op otherwise.
        NativeLogChannel.push(type, message, timestamp)
    }
}
