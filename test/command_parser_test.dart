import 'package:find_my_phone/src/core/security/emergency_code_hasher.dart';
import 'package:find_my_phone/src/core/sms/emergency_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses supported SMS commands', () {
    expect(EmergencyCommandParser.parse('LOCATE ABC123')?.type, EmergencyCommandType.locate);
    expect(EmergencyCommandParser.parse('SILENTLOCATE ABC123')?.type, EmergencyCommandType.silentLocate);
    expect(EmergencyCommandParser.parse('ALARM ABC123')?.type, EmergencyCommandType.alarm);
    expect(EmergencyCommandParser.parse('INFO ABC123')?.type, EmergencyCommandType.info);
    expect(EmergencyCommandParser.parse('LOCK ABC123')?.type, EmergencyCommandType.lock);
    expect(EmergencyCommandParser.parse('RESET NEWCODE1')?.type, EmergencyCommandType.resetCode);
    expect(EmergencyCommandParser.parse('LIVETRACK ABC123')?.type, EmergencyCommandType.liveTrack);
  });

  test('parses Arabic SMS commands', () {
    expect(EmergencyCommandParser.parse('موقع ABC123')?.type, EmergencyCommandType.locate);
    expect(EmergencyCommandParser.parse('موقع_صامت ABC123')?.type, EmergencyCommandType.silentLocate);
    expect(EmergencyCommandParser.parse('انذار ABC123')?.type, EmergencyCommandType.alarm);
    expect(EmergencyCommandParser.parse('إنذار ABC123')?.type, EmergencyCommandType.alarm);
    expect(EmergencyCommandParser.parse('معلومات ABC123')?.type, EmergencyCommandType.info);
    expect(EmergencyCommandParser.parse('قفل ABC123')?.type, EmergencyCommandType.lock);
    expect(EmergencyCommandParser.parse('استرجاع NEWCODE1')?.type, EmergencyCommandType.resetCode);
    expect(EmergencyCommandParser.parse('إعادة_تعيين NEWCODE1')?.type, EmergencyCommandType.resetCode);
    expect(EmergencyCommandParser.parse('تتبع_مباشر ABC123')?.type, EmergencyCommandType.liveTrack);
  });

  test('rejects malformed commands', () {
    expect(EmergencyCommandParser.parse('LOCATE'), isNull);
    expect(EmergencyCommandParser.parse('WIPE ABC123'), isNull);
    expect(EmergencyCommandParser.parse('LOCATE ABC123 EXTRA'), isNull);
  });

  test('validates emergency code format', () {
    expect(EmergencyCodeHasher.isValidFormat('ABC123'), isTrue);
    expect(EmergencyCodeHasher.isValidFormat('A1B2C3D4E5F6'), isTrue);
    expect(EmergencyCodeHasher.isValidFormat('12345'), isFalse);
    expect(EmergencyCodeHasher.isValidFormat('ABC1234567890'), isFalse);
    expect(EmergencyCodeHasher.isValidFormat('ABC-123'), isFalse);
  });

  test('hashes and verifies code without storing plaintext', () {
    final salt = EmergencyCodeHasher.generateSalt();
    final hash = EmergencyCodeHasher.hash('ABC123', salt);
    expect(hash, isNot('ABC123'));
    expect(EmergencyCodeHasher.verify('ABC123', salt, hash), isTrue);
    expect(EmergencyCodeHasher.verify('ABC124', salt, hash), isFalse);
  });
}
