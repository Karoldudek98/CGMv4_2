// lib/models/cgm_alert.dart
import 'package:flutter/material.dart';

// Enum definiujący typy alertów
enum AlertType {
  highGlucose, // Za wysoki poziom glukozy
  lowGlucose,  // Za niski poziom glukozy
  signalLoss,  // Utrata sygnału (brak danych)
}

// Klasa reprezentująca pojedynczy alert glikemii lub sygnału
class CgmAlert {
  final AlertType type; // Typ alertu (np. highGlucose, signalLoss)
  final DateTime timestamp; // Czas, kiedy alert został wygenerowany
  final double? glucoseValue; // Wartość glukozy (opcjonalna, np. dla alertów sygnału nie ma wartości)
  final String message; // Treść komunikatu alertu
  bool isRead; // Czy alert został przez użytkownika "przeczytany" lub zaakceptowany

  CgmAlert({
    required this.type,
    required this.timestamp,
    this.glucoseValue,
    required this.message,
    this.isRead = false,
  });

  // Getter zwracający kolor dla danego typu alertu, przydatny w UI
  Color get alertColor {
    switch (type) {
      case AlertType.highGlucose:
        return Colors.red.shade700;
      case AlertType.lowGlucose:
        return Colors.red.shade700;
      case AlertType.signalLoss:
        return Colors.orange.shade700;
    }
  }

  // Metoda do oznaczenia alertu jako przeczytany
  void markAsRead() {
    isRead = true;
  }
}