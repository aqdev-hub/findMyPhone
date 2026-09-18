import '../../../core/phone_normalizer.dart';

enum TrustedContactRole { primary, secondary, backup, additional }

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final TrustedContactRole role;
  final DateTime createdAt;

  String get normalizedPhone => PhoneNormalizer.normalize(phone);

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': normalizedPhone,
        'role': role.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory TrustedContact.fromMap(Map<String, Object?> map) => TrustedContact(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String,
        role: TrustedContactRole.values.byName(map['role'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
