enum LocationSource { gps, approximate, lastKnown }

class KnownLocation {
  const KnownLocation({
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.createdAt,
  });

  final double latitude;
  final double longitude;
  final LocationSource source;
  final DateTime createdAt;

  String get mapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';

  Map<String, Object?> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'source': source.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory KnownLocation.fromMap(Map<String, Object?> map) => KnownLocation(
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        source: LocationSource.values.byName(map['source'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
