package com.findmyphone.find_my_phone

import android.app.admin.DevicePolicyManager
import android.content.Intent
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Method channel: Dart → Native calls ─────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NativeStore.CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "syncSecurityState" -> {
                        NativeStore.syncSecurityState(this, call.arguments as Map<*, *>)
                        result.success(null)
                    }
                    "saveLastKnownLocation" -> {
                        NativeStore.saveLastKnownLocation(this, call.arguments as Map<*, *>)
                        result.success(null)
                    }
                    "captureSimBaseline" -> result.success(NativeStore.captureSimBaseline(this))

                    "stopAlarm" -> {
                        // Stopping the service (rather than relying on a custom intent action)
                        // works reliably even if the service is mid-startup, and immediately
                        // triggers onDestroy() which stops the sound/vibration.
                        stopService(Intent(this, AlarmForegroundService::class.java))
                        result.success(null)
                    }

                    "triggerAlarm" -> {
                        // Same code path as the ALARM/انذار SMS command — lets
                        // "Test Alarm" in Settings actually start the siren so
                        // the user can verify it (and Stop Alarm) really work.
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, AlarmForegroundService::class.java)
                        )
                        result.success(null)
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }

                    "isBatteryOptimizationIgnored" -> {
                        result.success(isBatteryOptimizationIgnored())
                    }

                    "getPendingNativeLogs" -> {
                        result.success(NativeStore.getPendingNativeLogs(this))
                    }

                    "clearPendingNativeLogs" -> {
                        NativeStore.clearPendingNativeLogs(this)
                        result.success(null)
                    }

                    "isDeviceAdminActive" -> {
                        result.success(DeviceAdminUtil.isActive(this))
                    }

                    "requestDeviceAdminActivation" -> {
                        if (DeviceAdminUtil.isActive(this)) {
                            result.success(null)
                        } else {
                            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, DeviceAdminUtil.componentName(this@MainActivity))
                                putExtra(
                                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                    "تفعيل هذا يمنع إلغاء تثبيت التطبيق مباشرة ويُفعّل قفل الجهاز عن بُعد.\n" +
                                        "Activating this prevents the app from being uninstalled directly and enables remote device lock."
                                )
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                    }

                    "lockDeviceNow" -> {
                        val locked = DeviceAdminUtil.lockNow(this)
                        if (locked) {
                            result.success(null)
                        } else {
                            result.error(
                                "device_admin_inactive",
                                "Device admin is not active — activate Anti-Uninstall Protection first.",
                                null
                            )
                        }
                    }

                    "openAutoStartSettings" -> {
                        AutoStartHelper.open(this)
                        result.success(null)
                    }

                    "isLiveTrackingActive" -> {
                        result.success(NativeStore.isLiveTrackingActive(this))
                    }

                    "stopLiveTracking" -> {
                        NativeStore.setLiveTrackingActive(this, false)
                        stopService(Intent(this, LiveTrackingService::class.java))
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("native_error", error.message, null)
            }
        }

        // ── Event channel: Native → Dart real-time log stream ───────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NativeLogChannel.CHANNEL_NAME)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeLogChannel.setSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    NativeLogChannel.setSink(null)
                }
            })
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        NativeLogChannel.setSink(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        val powerManager = getSystemService(PowerManager::class.java) ?: return false
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        try {
            if (isBatteryOptimizationIgnored()) return
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Some OEMs (e.g. MIUI) restrict this intent — fall back to the general
            // battery-optimization settings screen so the user can still act.
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                // Nothing more we can do; Flutter side will just re-check the status.
            }
        }
    }
}
