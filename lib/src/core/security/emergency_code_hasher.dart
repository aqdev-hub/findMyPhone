import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class EmergencyCodeHasher {
  static final _allowed = RegExp(r'^[A-Za-z0-9]{6,12}$');

  static bool isValidFormat(String code) => _allowed.hasMatch(code);

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hash(String code, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$code'));
    for (var i = 0; i < 120000; i++) {
      digest = sha256.convert([...digest.bytes, ...utf8.encode(salt)]);
    }
    return base64UrlEncode(digest.bytes);
  }

  static bool verify(String code, String salt, String expectedHash) {
    if (!isValidFormat(code)) return false;
    return hash(code, salt) == expectedHash;
  }
}
