// lib/models/sgv_entry.dart

class SgvEntry {
  final String id;
  final double sgv;
  /// Czas odczytu SGV.
  final DateTime date;
  final String direction;
  final String units;

  SgvEntry({
    required this.id,
    required this.sgv,
    required this.date,
    required this.direction,
    required this.units,
  });

  factory SgvEntry.fromJson(Map<String, dynamic> json) {
    return SgvEntry(
      id: json['_id'] as String,
      sgv: (json['sgv'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      direction: json['direction'] as String? ?? 'Unknown',
      units: json['units'] as String? ?? 'mg/dL',
    );
  }
}