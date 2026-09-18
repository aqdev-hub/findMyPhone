package com.findmyphone.find_my_phone

import io.flutter.plugin.common.EventChannel

/**
 * NativeLogChannel — EventChannel sink holder for pushing native log events to Dart.
 *
 * This is a one-way channel: Native → Dart.
 *
 * USAGE:
 *   When the Flutter Engine is active (app is in foreground or background service
 *   with engine), Workers CAN send events through this sink in real time.
 *   When the engine is NOT active (app is killed), events accumulate in
 *   EncryptedSharedPreferences under "pending_native_logs" and are drained
 *   when the app opens via MainActivity.getPendingNativeLogs().
 *
 * The sink is registered in MainActivity.configureFlutterEngine()
 * and cleared in MainActivity.cleanUpFlutterEngine().
 */
object NativeLogChannel {
    const val CHANNEL_NAME = "find_my_phone/native_logs"

    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun setSink(s: EventChannel.EventSink?) {
        sink = s
    }

    /**
     * Attempt to push a log event to the Dart side.
     * Safe to call from any thread. No-op if Flutter Engine is not running.
     *
     * @param type      log type string, e.g. "sms_accepted", "alarm", "sim_change"
     * @param message   human-readable log message (Arabic or English)
     * @param timestamp ISO-8601 timestamp string
     */
    fun push(type: String, message: String, timestamp: String) {
        val s = sink ?: return
        // EventSink.success() must be called on the main (platform) thread.
        // Workers run on background threads — use Handler to post to main thread.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                s.success(mapOf("type" to type, "message" to message, "timestamp" to timestamp))
            } catch (_: Exception) {
                // Engine may have been destroyed between the null check and this post
            }
        }
    }
}
