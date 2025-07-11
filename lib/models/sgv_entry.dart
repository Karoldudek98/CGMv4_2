// lib/models/sgv_entry.dart

/// Klasa reprezentująca pojedynczy odczyt glikemii (SGV) z Nightscout.
/// Jest to model danych, który odwzorowuje strukturę danych otrzymywanych z API.
class SgvEntry {
  /// Unikalne ID odczytu z Nightscout, np. "65123abc...".
  final String id;
  /// Wartość glikemii (Blood Glucose Value) zawsze w mg/dL z API Nightscout.
  final double sgv;
  /// Czas odczytu SGV.
  final DateTime date;
  /// Kierunek zmiany glikemii, np. "Flat", "DoubleUp", "SingleDown".
  final String direction;
  /// Jednostki, w jakich pierwotnie przyszedł odczyt z Nightscout (zazwyczaj "mg/dL").
  final String units;

  /// Konstruktor dla klasy SgvEntry.
  SgvEntry({
    required this.id,
    required this.sgv,
    required this.date,
    required this.direction,
    required this.units,
  });

  /// Konstruktor fabryczny do tworzenia obiektu SgvEntry z mapy JSON.
  /// Nightscout API zwraca dane jako JSON, które Dart parsowałby jako Map<String, dynamic>.
  /// Ta metoda przekształca tę mapę w silnie typowany obiekt SgvEntry.
  factory SgvEntry.fromJson(Map<String, dynamic> json) {
    return SgvEntry(
      id: json['_id'] as String, // Nightscout używa '_id' jako unikalnego identyfikatora
      sgv: (json['sgv'] as num).toDouble(), // Wartość glikemii (może być int lub double w JSON)
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int), // Czas odczytu w milisekundach od Epoki
      direction: json['direction'] as String? ?? 'Unknown', // Kierunek, jeśli brak, ustaw na 'Unknown'
      units: json['units'] as String? ?? 'mg/dL', // Jednostki, jeśli brak, ustaw na 'mg/dL'
    );
  }
}