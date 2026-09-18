package com.findmyphone.find_my_phone

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

object NativeStore {
    const val CHANNEL = "find_my_phone/native"
    private const val PREFS = "find_my_phone_secure_native"
    const val PENDING_LOGS_KEY = "pending_native_logs"

    fun prefs(context: Context) = EncryptedSharedPreferences.create(
        context,
        PREFS,
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun syncSecurityState(context: Context, args: Map<*, *>) {
        val contacts = JSONArray()
        (args["contacts"] as? List<*>)?.forEach { item ->
            if (item is Map<*, *>) {
                contacts.put(JSONObject().apply {
                    put("id", item["id"]?.toString().orEmpty())
                    put("name", item["name"]?.toString().orEmpty())
                    put("phone", normalizePhone(item["phone"]?.toString().orEmpty()))
                    put("role", item["role"]?.toString().orEmpty())
                })
            }
        }
        prefs(context).edit()
            .putBoolean("enabled", args["enabled"] as? Boolean ?: false)
            .putString("code_salt", args["codeSalt"]?.toString().orEmpty())
            .putString("code_hash", args["codeHash"]?.toString().orEmpty())
            .putString("contacts", contacts.toString())
            .putInt("contact_limit", args["contactLimit"] as? Int ?: 10)
            .putBoolean("alert_all_contacts_on_sim_change", args["alertAllContactsOnSimChange"] as? Boolean ?: false)
            .apply()
    }

    fun saveLastKnownLocation(context: Context, args: Map<*, *>) {
        prefs(context).edit()
            .putString("last_latitude", args["latitude"]?.toString().orEmpty())
            .putString("last_longitude", args["longitude"]?.toString().orEmpty())
            .putString("last_location_time", args["timestamp"]?.toString().orEmpty())
            .apply()
    }

    /**
     * Returns the JSON array (as a String) of audit log entries accumulated by
     * SmsProcessorWorker while the Flutter engine was not running. Called by
     * MainActivity's "getPendingNativeLogs" method-channel handler on app open.
     */
    fun getPendingNativeLogs(context: Context): String =
        prefs(context).getString(PENDING_LOGS_KEY, "[]") ?: "[]"

    /**
     * Clears the pending native logs after the Flutter app has read and
     * persisted them into SQLCipher. Called by MainActivity's
     * "clearPendingNativeLogs" method-channel handler.
     */
    fun clearPendingNativeLogs(context: Context) {
        prefs(context).edit().remove(PENDING_LOGS_KEY).apply()
    }

    fun captureSimBaseline(context: Context): Map<String, Any?> {
        val fingerprint = simFingerprint(context)
        prefs(context).edit().putString("sim_baseline", JSONObject(fingerprint).toString()).apply()
        return fingerprint
    }

    fun simChanged(context: Context): Boolean {
        val baseline = prefs(context).getString("sim_baseline", null) ?: return false
        return baseline != JSONObject(simFingerprint(context)).toString()
    }

    fun markCurrentSimAsBaseline(context: Context) {
        prefs(context).edit().putString("sim_baseline", JSONObject(simFingerprint(context)).toString()).apply()
    }

    fun trustedContacts(context: Context): List<TrustedContactNative> {
        val raw = prefs(context).getString("contacts", "[]") ?: "[]"
        val array = JSONArray(raw)
        return (0 until array.length()).map { i ->
            val item = array.getJSONObject(i)
            TrustedContactNative(
                phone = normalizePhone(item.optString("phone")),
                role = item.optString("role"),
            )
        }
    }

    fun alertRecipients(context: Context): List<String> {
        val contacts = trustedContacts(context)
        val ordered = listOf("primary", "secondary", "backup")
            .flatMap { role -> contacts.filter { it.role == role }.map { it.phone } }
        if (prefs(context).getBoolean("alert_all_contacts_on_sim_change", false)) {
            return (ordered + contacts.map { it.phone }).distinct()
        }
        return ordered.distinct()
    }

    fun isTrusted(context: Context, sender: String): Boolean {
        val normalized = normalizePhone(sender)
        return trustedContacts(context).any { it.phone == normalized }
    }

    fun enabled(context: Context) = prefs(context).getBoolean("enabled", false)

    // ── Live tracking (remote, SMS-activated) ───────────────────────────────
    // Only ever stopped from within the app itself (by design — see
    // LiveTrackingService), so this state must survive process death and
    // device reboot to be resumed automatically.
    fun isLiveTrackingActive(context: Context) =
        prefs(context).getBoolean("live_tracking_active", false)

    fun liveTrackingRequester(context: Context): String? =
        prefs(context).getString("live_tracking_requester", null)

    fun setLiveTrackingActive(context: Context, active: Boolean, requester: String? = null) {
        val editor = prefs(context).edit().putBoolean("live_tracking_active", active)
        if (active && requester != null) {
            editor.putString("live_tracking_requester", requester)
        } else if (!active) {
            editor.remove("live_tracking_requester")
        }
        editor.apply()
    }
    fun codeSalt(context: Context) = prefs(context).getString("code_salt", "").orEmpty()
    fun codeHash(context: Context) = prefs(context).getString("code_hash", "").orEmpty()

    /**
     * Persists a new emergency code (salt + hash), used by the RESET/استرجاع
     * SMS command. The caller is responsible for verifying the sender is a
     * pre-registered trusted contact before calling this — RESET intentionally
     * does not require the old code (that's the whole point: recovery for a
     * forgotten code), so trust is anchored entirely on phone-number
     * registration instead.
     */
    fun setCode(context: Context, salt: String, hash: String) {
        prefs(context).edit()
            .putString("code_salt", salt)
            .putString("code_hash", hash)
            .apply()
    }

    // ── Brute-force protection ──────────────────────────────────────────────
    // Tracks failed emergency-code attempts (from any sender) in a rolling
    // window. After too many failures, command processing is temporarily
    // locked out and every trusted contact is alerted — since a forgotten
    // code from the real owner is rare, but repeated wrong guesses from an
    // SMS address is a real signal worth surfacing.
    private const val MAX_FAILED_ATTEMPTS = 5
    private const val LOCKOUT_WINDOW_MS = 15L * 60 * 1000 // 15 minutes

    /** Records a failed code attempt; returns the count within the current window. */
    fun recordFailedAttempt(context: Context): Int {
        val p = prefs(context)
        val now = System.currentTimeMillis()
        val windowStart = p.getLong("failed_window_start", 0L)
        val stillInWindow = now - windowStart < LOCKOUT_WINDOW_MS
        val count = if (stillInWindow) p.getInt("failed_count", 0) + 1 else 1
        p.edit()
            .putInt("failed_count", count)
            .putLong("failed_window_start", if (stillInWindow) windowStart else now)
            .apply()
        return count
    }

    fun resetFailedAttempts(context: Context) {
        prefs(context).edit().putInt("failed_count", 0).apply()
    }

    /** True while the command channel is locked out due to repeated failures. */
    fun isLockedOut(context: Context): Boolean {
        val p = prefs(context)
        val now = System.currentTimeMillis()
        val windowStart = p.getLong("failed_window_start", 0L)
        val inWindow = now - windowStart < LOCKOUT_WINDOW_MS
        return inWindow && p.getInt("failed_count", 0) >= MAX_FAILED_ATTEMPTS
    }

    fun normalizePhone(value: String): String {
        val trimmed = value.trim()
        val digits = trimmed.filter { it.isDigit() }
        return if (trimmed.startsWith("+")) "+$digits" else digits
    }

    private fun simFingerprint(context: Context): Map<String, Any?> {
        val manager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val result = linkedMapOf<String, Any?>(
            "simState" to manager.simState,
            "networkCountryIso" to manager.networkCountryIso.orEmpty(),
            "simCountryIso" to manager.simCountryIso.orEmpty(),
            "networkOperatorName" to manager.networkOperatorName.orEmpty(),
            "phoneType" to manager.phoneType,
        )
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
            val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            val subscriptions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                subscriptionManager.activeSubscriptionInfoList.orEmpty().map {
                    mapOf(
                        "carrierName" to it.carrierName?.toString().orEmpty(),
                        "countryIso" to it.countryIso.orEmpty(),
                        "mcc" to it.mccString.orEmpty(),
                        "mnc" to it.mncString.orEmpty(),
                        "simSlotIndex" to it.simSlotIndex,
                        "subscriptionId" to it.subscriptionId,
                    )
                }
            } else {
                emptyList()
            }
            result["subscriptions"] = JSONArray(subscriptions).toString()
            result["subscriptionCount"] = subscriptions.size
        }
        return result
    }
}

data class TrustedContactNative(val phone: String, val role: String)
