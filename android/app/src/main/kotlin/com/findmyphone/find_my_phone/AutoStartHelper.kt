package com.findmyphone.find_my_phone

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * AutoStartHelper — mitigates a well-known Android fragmentation problem:
 * many OEM Android skins (Xiaomi/MIUI, Oppo/ColorOS, Vivo/FuntouchOS,
 * Huawei/EMUI, Honor/Magic UI, Asus, Letv, and many regional/budget
 * white-label devices built on similar customized skins) silently kill
 * background broadcast receivers and WorkManager jobs unless the app is
 * explicitly whitelisted in a manufacturer-specific "autostart" /
 * "protected apps" / "background app management" screen — something the
 * standard Android REQUEST_IGNORE_BATTERY_OPTIMIZATIONS API does NOT cover
 * on these skins. This is the single most common reason a correctly-coded,
 * correctly-permissioned app never receives its SMS broadcast on certain
 * devices while working perfectly on stock/near-stock Android.
 *
 * We try a list of known manufacturer intents in order; the first one that
 * successfully resolves to an installed Activity is launched. If none
 * resolve, we fall back to this app's own details screen, which is at
 * least a useful starting point for the general "background restrictions"
 * subsection most OEM settings apps show there.
 */
object AutoStartHelper {
    private val knownIntents: List<Intent> = listOf(
        // Xiaomi / MIUI / Redmi / POCO
        Intent().setComponent(
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )
        ),
        // Oppo / ColorOS / Realme
        Intent().setComponent(
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity"
            )
        ),
        Intent().setComponent(
            ComponentName(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity"
            )
        ),
        // Vivo / FuntouchOS / iQOO
        Intent().setComponent(
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
            )
        ),
        // Huawei / EMUI
        Intent().setComponent(
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            )
        ),
        // Honor / Magic UI
        Intent().setComponent(
            ComponentName(
                "com.hihonor.systemmanager",
                "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            )
        ),
        // Asus
        Intent().setComponent(
            ComponentName(
                "com.asus.mobilemanager",
                "com.asus.mobilemanager.autostart.AutoStartActivity"
            )
        ),
        // Letv
        Intent().setComponent(
            ComponentName(
                "com.letv.android.letvsafe",
                "com.letv.android.letvsafe.AutobootManageActivity"
            )
        ),
        // Samsung (sleeping apps / put unused apps to sleep)
        Intent().setComponent(
            ComponentName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            )
        ),
    )

    /**
     * Opens whichever OEM autostart screen resolves first, or the app's own
     * details screen as a fallback. Always safe to call — never throws.
     */
    fun open(context: Context) {
        for (intent in knownIntents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(intent)
                    return
                }
            } catch (_: ActivityNotFoundException) {
                // Try the next known manufacturer intent
            } catch (_: Exception) {
                // Some OEMs restrict resolveActivity/startActivity for these
                // hidden components even when they technically exist —
                // never let this crash the caller.
            }
        }
        // Fallback: this app's own details screen.
        try {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", context.packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(fallback)
        } catch (_: Exception) {
            // Nothing more we can do.
        }
    }
}
