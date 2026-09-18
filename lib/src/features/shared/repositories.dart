import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/native/native_bridge.dart';
import '../../core/phone_normalizer.dart';
import '../../core/security/emergency_code_hasher.dart';
import '../../data/app_database.dart';
import '../location/domain/known_location.dart';
import '../logs/domain/audit_log.dart';
import '../trusted_contacts/domain/trusted_contact.dart';

class SettingsRepository {
  SettingsRepository(this._db, this._nativeBridge);
  final AppDatabase _db;
  final NativeBridge _nativeBridge;

  Future<String?> read(String key) async {
    final db = await _db.instance;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> write(String key, String value, {Transaction? txn}) async {
    final db = txn ?? await _db.instance;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isSetupComplete() async {
    final phone = await read('phone');
    final hash = await read('code_hash');
    final hasPrimary = await _hasPrimaryContact();
    return phone != null && hash != null && hasPrimary;
  }

  Future<int> trustedContactsLimit() async {
    final raw = await read('trusted_contacts_limit');
    final parsed = int.tryParse(raw ?? '');
    return (parsed ?? AppConstants.defaultTrustedContactsLimit).clamp(1, AppConstants.maxTrustedContactsLimit);
  }

  Future<void> setTrustedContactsLimit(int limit) async {
    final safeLimit = limit.clamp(1, AppConstants.maxTrustedContactsLimit);
    await write('trusted_contacts_limit', safeLimit.toString());
    await syncNativeState();
  }

  Future<void> saveEmergencyCode(String code) async {
    if (!EmergencyCodeHasher.isValidFormat(code)) {
      throw const AppException('رمز الطوارئ يجب أن يكون 6-12 حرفًا أو رقمًا إنجليزيًا.');
    }
    final salt = EmergencyCodeHasher.generateSalt();
    final hash = EmergencyCodeHasher.hash(code, salt);
    final db = await _db.instance;
    await db.transaction((txn) async {
      await write('code_salt', salt, txn: txn);
      await write('code_hash', hash, txn: txn);
    });
    await syncNativeState();
  }

  Future<void> savePhone(String phone) => write('phone', PhoneNormalizer.normalize(phone));

  Future<void> setAlertAllContactsOnSimChange(bool enabled) async {
    await write('alert_all_contacts_on_sim_change', enabled ? 'true' : 'false');
    await syncNativeState();
  }

  Future<bool> alertAllContactsOnSimChange() async => (await read('alert_all_contacts_on_sim_change')) == 'true';

  Future<void> syncNativeState() async {
    final salt = await read('code_salt') ?? '';
    final hash = await read('code_hash') ?? '';
    final contacts = await TrustedContactsRepository(_db, this).all();
    final limit = await trustedContactsLimit();
    await _nativeBridge.syncSecurityState(
      enabled: await isSetupComplete(),
      codeSalt: salt,
      codeHash: hash,
      contacts: contacts,
      contactLimit: limit,
      alertAllContactsOnSimChange: await alertAllContactsOnSimChange(),
    );
  }

  Future<bool> _hasPrimaryContact() async {
    final db = await _db.instance;
    final rows = await db.query('trusted_contacts', where: 'role = ?', whereArgs: ['primary'], limit: 1);
    return rows.isNotEmpty;
  }

  Future<Map<String, Object?>> captureSimBaseline() => _nativeBridge.captureSimBaseline();
}

class TrustedContactsRepository {
  TrustedContactsRepository(this._db, this._settings);
  final AppDatabase _db;
  final SettingsRepository _settings;

  Future<List<TrustedContact>> all() async {
    final db = await _db.instance;
    final rows = await db.query('trusted_contacts', orderBy: 'created_at ASC');
    return rows.map(TrustedContact.fromMap).toList();
  }

  Future<void> add(String name, String phone, TrustedContactRole role) async {
    final contacts = await all();
    final limit = await _settings.trustedContactsLimit();
    if (contacts.length >= limit) throw AppException('وصلت إلى الحد الأقصى ($limit) لجهات الاتصال.');
    if (contacts.any((c) => PhoneNormalizer.same(c.phone, phone))) throw const AppException('الرقم موجود مسبقًا.');
    if (role == TrustedContactRole.primary && contacts.any((c) => c.role == TrustedContactRole.primary)) {
      throw const AppException('يمكن تعيين رقم أساسي واحد فقط.');
    }
    final contact = TrustedContact(
      id: const Uuid().v4(),
      name: name.trim().isEmpty ? 'جهة موثوقة' : name.trim(),
      phone: PhoneNormalizer.normalize(phone),
      role: role,
      createdAt: DateTime.now(),
    );
    final db = await _db.instance;
    await db.insert('trusted_contacts', contact.toMap());
    await _settings.syncNativeState();
  }

  Future<void> delete(String id) async {
    final db = await _db.instance;
    await db.delete('trusted_contacts', where: 'id = ?', whereArgs: [id]);
    await _settings.syncNativeState();
  }
}

class LocationRepository {
  LocationRepository(this._db, this._nativeBridge);
  final AppDatabase _db;
  final NativeBridge _nativeBridge;

  Future<void> save(KnownLocation location) async {
    final db = await _db.instance;
    await db.insert('locations', location.toMap());
    await _nativeBridge.saveLastKnownLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: location.createdAt.toIso8601String(),
    );
  }

  Future<KnownLocation?> lastKnown() async {
    final db = await _db.instance;
    final rows = await db.query('locations', orderBy: 'created_at DESC', limit: 1);
    return rows.isEmpty ? null : KnownLocation.fromMap(rows.first);
  }
}

class AuditLogRepository {
  AuditLogRepository(this._db);
  final AppDatabase _db;

  Future<void> add(String type, String message) async {
    final db = await _db.instance;
    await db.insert('audit_logs', AuditLog(type: type, message: message, createdAt: DateTime.now()).toMap());
  }

  Future<List<AuditLog>> latest() async {
    final db = await _db.instance;
    final rows = await db.query('audit_logs', orderBy: 'created_at DESC', limit: 200);
    return rows.map(AuditLog.fromMap).toList();
  }
}

// ── Additional settings (appended) ───────────────────────────────────────────

extension SettingsRepositoryExtensions on SettingsRepository {
  Future<bool> alarmEnabled() async => (await read('alarm_enabled')) != 'false';
  Future<void> setAlarmEnabled(bool v) async {
    await write('alarm_enabled', v ? 'true' : 'false');
  }

  Future<bool> simGuardEnabled() async => (await read('sim_guard_enabled')) != 'false';
  Future<void> setSimGuardEnabled(bool v) async {
    await write('sim_guard_enabled', v ? 'true' : 'false');
    await syncNativeState();
  }
}

// ── App Lock (tamper protection) ─────────────────────────────────────────────
// Gates the app itself behind a PIN so someone who has the phone temporarily
// can't open the app and change trusted contacts, disable protection, etc.
// Reuses EmergencyCodeHasher's hashing so no new crypto surface is introduced.
extension AppLockRepositoryExtensions on SettingsRepository {
  Future<bool> appLockEnabled() async => (await read('app_lock_enabled')) == 'true';

  Future<void> setAppLockEnabled(bool v) async {
    await write('app_lock_enabled', v ? 'true' : 'false');
  }

  /// Whether a separate app-lock PIN has been set. If false, [verifyAppLock]
  /// falls back to the emergency code — so tamper protection works
  /// immediately when enabled, even before the user picks a dedicated PIN.
  Future<bool> hasCustomAppLockPin() async => (await read('app_lock_hash')) != null;

  Future<void> setAppLockPin(String pin) async {
    if (!EmergencyCodeHasher.isValidFormat(pin)) {
      throw const AppException('رمز القفل يجب أن يكون 6-12 حرفًا أو رقمًا إنجليزيًا.');
    }
    final salt = EmergencyCodeHasher.generateSalt();
    final hash = EmergencyCodeHasher.hash(pin, salt);
    final db = await _db.instance;
    await db.transaction((txn) async {
      await write('app_lock_salt', salt, txn: txn);
      await write('app_lock_hash', hash, txn: txn);
    });
  }

  /// Removes the custom PIN — verification then falls back to the
  /// emergency code again, it does not disable app lock itself.
  Future<void> clearAppLockPin() async {
    final db = await _db.instance;
    await db.delete('settings', where: 'key IN (?, ?)', whereArgs: ['app_lock_salt', 'app_lock_hash']);
  }

  Future<bool> verifyAppLock(String input) async {
    final customHash = await read('app_lock_hash');
    if (customHash != null) {
      final salt = await read('app_lock_salt') ?? '';
      return EmergencyCodeHasher.verify(input, salt, customHash);
    }
    // No dedicated PIN set — the emergency code doubles as the app-lock code.
    final codeHash = await read('code_hash');
    final codeSalt = await read('code_salt');
    if (codeHash == null || codeSalt == null) return false;
    return EmergencyCodeHasher.verify(input, codeSalt, codeHash);
  }
}
