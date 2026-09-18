import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../constants.dart';
import '../../features/trusted_contacts/domain/trusted_contact.dart';

class PendingNativeLog {
  const PendingNativeLog({
    required this.type,
    required this.message,
    required this.timestamp,
  });
  final String type;
  final String message;
  final DateTime timestamp;

  factory PendingNativeLog.fromMap(Map<String, dynamic> map) =>
      PendingNativeLog(
        type: map['type'] as String? ?? 'unknown',
        message: map['message'] as String? ?? '',
        timestamp:
            DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

class NativeBridge {
  static const _ch = MethodChannel(AppConstants.nativeChannel);
  static const _logCh = EventChannel('find_my_phone/native_logs');

  Future<void> syncSecurityState({
    required bool enabled,
    required String codeSalt,
    required String codeHash,
    required List<TrustedContact> contacts,
    required int contactLimit,
    required bool alertAllContactsOnSimChange,
  }) =>
      _ch.invokeMethod('syncSecurityState', {
        'enabled': enabled,
        'codeSalt': codeSalt,
        'codeHash': codeHash,
        'contacts': contacts.map((c) => c.toMap()).toList(),
        'contactLimit': contactLimit,
        'alertAllContactsOnSimChange': alertAllContactsOnSimChange,
      });

  Future<void> saveLastKnownLocation({
    required double latitude,
    required double longitude,
    required String timestamp,
  }) =>
      _ch.invokeMethod('saveLastKnownLocation', {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp,
      });

  Future<Map<String, Object?>> captureSimBaseline() async {
    final result =
        await _ch.invokeMapMethod<String, Object?>('captureSimBaseline');
    return result ?? {};
  }

  Future<void> stopAlarm() => _ch.invokeMethod('stopAlarm');

  /// Starts the alarm foreground service directly (siren + vibration), the
  /// same code path the ALARM/انذار SMS command uses. Lets the user verify
  /// the alarm and the Stop Alarm button actually work, without needing a
  /// second phone to send a real SMS.
  Future<void> triggerAlarm() => _ch.invokeMethod('triggerAlarm');

  /// Whether this app is currently registered as a Device Admin.
  /// This is what powers the anti-uninstall friction: as long as it's true,
  /// Android requires the user to explicitly deactivate admin rights via the
  /// system Settings screen before the app can be uninstalled.
  Future<bool> isDeviceAdminActive() async {
    final result = await _ch.invokeMethod<bool>('isDeviceAdminActive');
    return result ?? false;
  }

  /// Opens the system "Activate device admin app" screen for this app.
  /// The system, not this app, controls that screen's outcome — the caller
  /// should re-check [isDeviceAdminActive] when the app resumes.
  Future<void> requestDeviceAdminActivation() =>
      _ch.invokeMethod('requestDeviceAdminActivation');

  /// Immediately locks the device screen (equivalent to a screen-lock
  /// power-button press). Requires device admin to be active — throws a
  /// [PlatformException] otherwise, which callers should surface to the user.
  Future<void> lockDeviceNow() => _ch.invokeMethod('lockDeviceNow');

  /// Opens the manufacturer-specific "autostart" / "protected apps" /
  /// "background app management" screen when a known one exists on this
  /// device (Xiaomi, Oppo, Vivo, Huawei, Honor, Asus, Letv, Samsung...),
  /// falling back to the app's own details screen otherwise. Many OEM
  /// Android skins silently kill background broadcast receivers unless the
  /// app is whitelisted here — something standard battery-optimization
  /// exemption alone does not cover on these skins.
  Future<void> openAutoStartSettings() =>
      _ch.invokeMethod('openAutoStartSettings');

  /// Whether live tracking (activated remotely via the LIVETRACK/تتبع_مباشر
  /// SMS command) is currently active on this device.
  Future<bool> isLiveTrackingActive() async {
    final result = await _ch.invokeMethod<bool>('isLiveTrackingActive');
    return result ?? false;
  }

  /// Stops live tracking. By design this is the ONLY way to stop it — it
  /// cannot be stopped remotely via SMS, so a thief can't turn it back off.
  Future<void> stopLiveTracking() => _ch.invokeMethod('stopLiveTracking');

  Future<void> requestIgnoreBatteryOptimizations() =>
      _ch.invokeMethod('requestIgnoreBatteryOptimizations');

  Future<bool> isBatteryOptimizationIgnored() async {
    final result =
        await _ch.invokeMethod<bool>('isBatteryOptimizationIgnored');
    return result ?? false;
  }

  Future<List<PendingNativeLog>> getPendingNativeLogs() async {
    final raw =
        await _ch.invokeMethod<String>('getPendingNativeLogs') ?? '[]';
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(PendingNativeLog.fromMap)
        .toList();
  }

  Future<void> clearPendingNativeLogs() =>
      _ch.invokeMethod('clearPendingNativeLogs');

  Stream<PendingNativeLog> get nativeLogStream =>
      _logCh.receiveBroadcastStream().map((event) {
        if (event is Map) {
          return PendingNativeLog.fromMap(Map<String, dynamic>.from(event));
        }
        return PendingNativeLog(
            type: 'unknown', message: event.toString(), timestamp: DateTime.now());
      });
}
