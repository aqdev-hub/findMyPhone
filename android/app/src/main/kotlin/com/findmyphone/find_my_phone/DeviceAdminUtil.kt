package com.findmyphone.find_my_phone

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context

/**
 * DeviceAdminUtil — shared helper around Android's Device Admin API.
 *
 * WHAT DEVICE ADMIN DOES HERE (be precise about this, it's a security feature):
 *   Once the user activates this app as a Device Admin, Android requires them
 *   to explicitly go to Settings → Security → Device admin apps → deactivate
 *   BEFORE the app can be uninstalled. Attempting "Uninstall" directly from
 *   the launcher/app-info screen is blocked by the OS while admin is active.
 *   This is a real, OS-enforced friction step — not a decoration.
 *
 * WHAT IT DOES NOT DO (be honest about the limit too):
 *   Android does not let a normal (non-Device-Owner) app gate that
 *   deactivation screen behind an in-app PIN — deactivation itself cannot be
 *   blocked outright, only slowed down and made visible. We compensate by:
 *     1) Showing a strong warning on that exact system screen
 *        (ProtectionDeviceAdminReceiver.onDisableRequested).
 *     2) Immediately alerting all trusted contacts by SMS the moment
 *        deactivation completes (ProtectionDeviceAdminReceiver.onDisabled).
 *
 * It also unlocks the LOCK / قفل SMS command via [lockNow], which requires
 * USES_POLICY_FORCE_LOCK — declared in res/xml/device_admin.xml.
 */
object DeviceAdminUtil {
    fun componentName(context: Context): ComponentName =
        ComponentName(context.applicationContext, ProtectionDeviceAdminReceiver::class.java)

    fun isActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            ?: return false
        return dpm.isAdminActive(componentName(context))
    }

    /**
     * Locks the screen immediately, equivalent to a screen-lock power-button
     * press. Returns true on success, false if device admin isn't active or
     * the platform call failed for any reason (e.g. no active screen lock
     * policy on some OEM builds) — callers must handle both cases explicitly
     * rather than assuming success.
     */
    fun lockNow(context: Context): Boolean {
        if (!isActive(context)) return false
        return try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            dpm.lockNow()
            true
        } catch (_: Exception) {
            false
        }
    }
}
