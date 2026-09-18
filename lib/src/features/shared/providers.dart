import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/native/native_bridge.dart';
import '../../data/app_database.dart';
import '../location/domain/known_location.dart';
import 'repositories.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────
final secureStorageProvider = Provider((_) => const FlutterSecureStorage());
final nativeBridgeProvider = Provider((_) => NativeBridge());
final appDatabaseProvider =
    Provider((ref) => AppDatabase(ref.watch(secureStorageProvider)));
final sharedPrefsProvider = FutureProvider((_) => SharedPreferences.getInstance());

// ── Repositories ──────────────────────────────────────────────────────────────
final settingsRepositoryProvider = Provider((ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider), ref.watch(nativeBridgeProvider)));
final contactsRepositoryProvider = Provider((ref) => TrustedContactsRepository(
    ref.watch(appDatabaseProvider), ref.watch(settingsRepositoryProvider)));
final locationRepositoryProvider = Provider((ref) =>
    LocationRepository(ref.watch(appDatabaseProvider), ref.watch(nativeBridgeProvider)));
final auditLogRepositoryProvider =
    Provider((ref) => AuditLogRepository(ref.watch(appDatabaseProvider)));

// ── Theme & Locale ────────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);
final localeProvider = StateProvider<Locale?>((_) => null); // null = use device locale

final stringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  final code = locale?.languageCode ?? 'ar';
  return AppStrings(code);
});

// ── Onboarding ────────────────────────────────────────────────────────────────
const _onboardingSeenKey = 'onboarding_seen';

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getBool(_onboardingSeenKey) ?? false;
});

Future<void> markOnboardingComplete(WidgetRef ref) async {
  final prefs = await ref.read(sharedPrefsProvider.future);
  await prefs.setBool(_onboardingSeenKey, true);
  ref.invalidate(onboardingCompleteProvider);
}

// ── Home shell ────────────────────────────────────────────────────────────────
// HomeScreen's outer Scaffold owns the drawer; each bottom-nav tab page has
// its own inner Scaffold (for its own AppBar). Scaffold.of(context) from
// inside a tab page resolves to that inner Scaffold — which has no drawer —
// so openDrawer() silently does nothing there. This shared key lets any tab's
// menu button reliably open the *outer* Scaffold's drawer instead.
final scaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>(
  (ref) => GlobalKey<ScaffoldState>(),
);

// ── UI Data ───────────────────────────────────────────────────────────────────
final setupCompleteProvider =
    FutureProvider((ref) => ref.watch(settingsRepositoryProvider).isSetupComplete());
final contactsProvider =
    FutureProvider((ref) => ref.watch(contactsRepositoryProvider).all());
final lastLocationProvider =
    FutureProvider((ref) => ref.watch(locationRepositoryProvider).lastKnown());
final logsProvider =
    FutureProvider((ref) => ref.watch(auditLogRepositoryProvider).latest());
final contactsLimitProvider =
    FutureProvider((ref) => ref.watch(settingsRepositoryProvider).trustedContactsLimit());
final alertAllContactsProvider =
    FutureProvider((ref) => ref.watch(settingsRepositoryProvider).alertAllContactsOnSimChange());
final alarmEnabledProvider =
    FutureProvider((ref) => ref.watch(settingsRepositoryProvider).alarmEnabled());
final simGuardEnabledProvider =
    FutureProvider((ref) => ref.watch(settingsRepositoryProvider).simGuardEnabled());

// ── Permissions ───────────────────────────────────────────────────────────────
final permissionsProvider = FutureProvider((_) async {
  return {
    'sms': await Permission.sms.status,
    'location': await Permission.location.status,
    'backgroundLocation': await Permission.locationAlways.status,
    'phone': await Permission.phone.status,
    'notifications': await Permission.notification.status,
    'vibrate': PermissionStatus.granted,
  };
});

final batteryOptIgnoredProvider = FutureProvider(
    (ref) => ref.watch(nativeBridgeProvider).isBatteryOptimizationIgnored());

final deviceAdminActiveProvider = FutureProvider(
    (ref) => ref.watch(nativeBridgeProvider).isDeviceAdminActive());

final liveTrackingActiveProvider = FutureProvider(
    (ref) => ref.watch(nativeBridgeProvider).isLiveTrackingActive());

final appLockEnabledProvider = FutureProvider(
    (ref) => ref.watch(settingsRepositoryProvider).appLockEnabled());
final hasCustomAppLockPinProvider = FutureProvider(
    (ref) => ref.watch(settingsRepositoryProvider).hasCustomAppLockPin());

// ── Location service ──────────────────────────────────────────────────────────
final locationCaptureProvider = Provider((ref) => LocationCaptureService(
    ref.watch(locationRepositoryProvider), ref.watch(auditLogRepositoryProvider)));

class LocationCaptureService {
  LocationCaptureService(this._locations, this._logs);
  final LocationRepository _locations;
  final AuditLogRepository _logs;

  /// The precise reason the most recent [capture] call didn't get a fresh
  /// fix, for on-screen diagnostics — e.g. "permission: deniedForever",
  /// "location services disabled", or the exact exception from each
  /// provider attempt. Null after a successful capture.
  String? lastFailureReason;

  Future<KnownLocation?> capture() async {
    lastFailureReason = null;

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      lastFailureReason = 'permission: $permission';
      await _logs.add('location', 'لم يتم منح إذن الموقع / Location permission denied ($permission).');
      return _locations.lastKnown();
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      lastFailureReason = 'location_services_disabled';
      await _logs.add('location', 'خدمة الموقع (GPS) مُعطّلة على الجهاز / Device location services are turned off.');
      return _locations.lastKnown();
    }

    final position = await _getPositionWithFallback();
    if (position != null) {
      final location = KnownLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        source: LocationSource.gps,
        createdAt: DateTime.now(),
      );
      await _locations.save(location);
      await _logs.add('location', 'تم تحديث الموقع / Location updated: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
      return location;
    }

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final location = KnownLocation(
        latitude: last.latitude,
        longitude: last.longitude,
        source: LocationSource.approximate,
        createdAt: DateTime.now(),
      );
      await _locations.save(location);
      await _logs.add('location', 'تم استخدام آخر موقع مخزّن بالنظام / Used the OS-level last-known position (permission: $permission).');
      return location;
    }

    await _logs.add(
      'location_failed',
      'تعذّر الحصول على أي موقع / Could not obtain any fix. permission=$permission, reason=$lastFailureReason',
    );
    return _locations.lastKnown();
  }

  /// Tries the battery-efficient FusedLocationProviderClient first, then
  /// falls back to the raw platform LocationManager if that fails or times
  /// out — some devices (especially budget/regional-market ones) ship with
  /// broken or missing Google Play Services, where forceLocationManager:false
  /// alone would silently never return a fix at all. Records the exact
  /// exception from each attempt in [lastFailureReason] rather than
  /// swallowing it, so a real failure can actually be diagnosed instead of
  /// guessed at.
  Future<Position?> _getPositionWithFallback() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
          forceLocationManager: false,
        ),
      );
    } catch (e) {
      lastFailureReason = 'fused_provider: $e';
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 12),
            forceLocationManager: true,
          ),
        );
      } catch (e2) {
        lastFailureReason = '${lastFailureReason!} | location_manager: $e2';
        return null;
      }
    }
  }
}

// ── Battery ───────────────────────────────────────────────────────────────────
final batterySummaryProvider = FutureProvider((_) async {
  final battery = Battery();
  final level = await battery.batteryLevel;
  final state = await battery.batteryState;
  final stateAr = switch (state) {
    BatteryState.charging => 'يشحن / Charging',
    BatteryState.full => 'مشحون / Full',
    BatteryState.discharging => 'يعمل / Discharging',
    _ => 'غير معروف / Unknown',
  };
  return '$level% — $stateAr';
});

// ── Native log stream ─────────────────────────────────────────────────────────
final nativeLogStreamProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(nativeBridgeProvider).nativeLogStream;
});
