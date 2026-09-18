import 'package:find_my_phone/src/core/sms/emergency_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project smoke test uses the current app command surface', () {
    final command = EmergencyCommandParser.parse('SILENTLOCATE ABC123');

    expect(command, isNotNull);
    expect(command!.type, EmergencyCommandType.silentLocate);
    expect(command.code, 'ABC123');
  });
}
