enum EmergencyCommandType { locate, silentLocate, alarm, info, lock, resetCode, liveTrack }

class EmergencyCommand {
  const EmergencyCommand(this.type, this.code);
  final EmergencyCommandType type;
  final String code;
}

class EmergencyCommandParser {
  /// Maps both English and Arabic command keywords to their command type.
  /// Arabic senders can use either the Arabic word or the English one.
  static const Map<String, EmergencyCommandType> _aliases = {
    'LOCATE': EmergencyCommandType.locate,
    'موقع': EmergencyCommandType.locate,
    'تحديد_الموقع': EmergencyCommandType.locate,

    'SILENTLOCATE': EmergencyCommandType.silentLocate,
    'موقع_صامت': EmergencyCommandType.silentLocate,
    'تتبع_صامت': EmergencyCommandType.silentLocate,

    'ALARM': EmergencyCommandType.alarm,
    'انذار': EmergencyCommandType.alarm,
    'إنذار': EmergencyCommandType.alarm,

    'INFO': EmergencyCommandType.info,
    'معلومات': EmergencyCommandType.info,

    'LOCK': EmergencyCommandType.lock,
    'قفل': EmergencyCommandType.lock,
    'قفل_الجهاز': EmergencyCommandType.lock,

    'RESET': EmergencyCommandType.resetCode,
    'استرجاع': EmergencyCommandType.resetCode,
    'إعادة_تعيين': EmergencyCommandType.resetCode,
    'اعادة_تعيين': EmergencyCommandType.resetCode,

    'LIVETRACK': EmergencyCommandType.liveTrack,
    'تتبع_مباشر': EmergencyCommandType.liveTrack,
  };

  static EmergencyCommand? parse(String body) {
    final parts = body.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    final code = parts[1];
    final type = _aliases[parts[0].toUpperCase()];
    if (type == null) return null;
    return EmergencyCommand(type, code);
  }

  /// The canonical keyword pair (English, Arabic) shown to users for a command type.
  static (String, String) keywordsFor(EmergencyCommandType type) => switch (type) {
        EmergencyCommandType.locate => ('LOCATE', 'موقع'),
        EmergencyCommandType.silentLocate => ('SILENTLOCATE', 'موقع_صامت'),
        EmergencyCommandType.alarm => ('ALARM', 'انذار'),
        EmergencyCommandType.info => ('INFO', 'معلومات'),
        EmergencyCommandType.lock => ('LOCK', 'قفل'),
        EmergencyCommandType.resetCode => ('RESET', 'استرجاع'),
        EmergencyCommandType.liveTrack => ('LIVETRACK', 'تتبع_مباشر'),
      };
}
