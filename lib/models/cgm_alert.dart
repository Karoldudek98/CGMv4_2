// lib/models/cgm_alert.dart
import 'package:flutter/material.dart'; // Potrzebne do typu Color

/// Klasa reprezentująca pojedynczy alert glikemii (np. niska lub wysoka glikemia).
class CgmAlert {
  /// Komunikat alertu, np. "Niska glikemia: 65 mg/dL".
  final String message;
  /// Czas wygenerowania alertu.
  final DateTime timestamp;
  /// Typ alertu (np. "LOW", "HIGH").
  final String type; // Zmieniono na String, aby pasowało do danych z NightscoutDataService
  /// Kolor alertu, np. Colors.red.
  final Color alertColor; // Dodano pole do przechowywania koloru
  /// Czy alert został już przeczytany.
  bool isRead;

  /// Konstruktor dla klasy CgmAlert.
  CgmAlert({
    required this.message,
    required this.timestamp,
    required this.type,
    required this.alertColor, // Dodano do konstruktora
    this.isRead = false, // Domyślnie alerty są nieprzeczytane
  });

  /// Metoda do serializacji obiektu CgmAlert do mapy JSON.
  /// Używane do zapisywania alertów w SharedPreferences.
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(), // Zapisz datę jako String ISO 8601
      'type': type,
      'alertColorValue': alertColor.value, // Zapisz wartość int koloru
      'isRead': isRead,
    };
  }

  /// Metoda fabryczna do tworzenia obiektu CgmAlert z mapy JSON.
  /// Używane do odczytywania alertów z SharedPreferences.
  factory CgmAlert.fromJson(Map<String, dynamic> json) {
    return CgmAlert(
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String), // Parsuj String z powrotem na DateTime
      type: json['type'] as String,
      alertColor: Color(json['alertColorValue'] as int), // Odtwórz Color z wartości int
      isRead: json['isRead'] as bool? ?? false, // Upewnij się, że isRead ma domyślną wartość
    );
  }
}