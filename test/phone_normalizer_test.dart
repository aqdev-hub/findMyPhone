import 'package:find_my_phone/src/core/phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes trusted contact phone numbers', () {
    expect(PhoneNormalizer.normalize('+967 777 123 456'), '+967777123456');
    expect(PhoneNormalizer.normalize('777-123-456'), '777123456');
    expect(PhoneNormalizer.same('+967 777 123 456', '+967777123456'), isTrue);
  });
}
