class AuditLog {
  const AuditLog({required this.type, required this.message, required this.createdAt});
  final String type;
  final String message;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'type': type,
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };

  factory AuditLog.fromMap(Map<String, Object?> map) => AuditLog(
        type: map['type'] as String,
        message: map['message'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
