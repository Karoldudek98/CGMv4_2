// lib/services/settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cgmv4/models/glucose_unit.dart';

/// Serwis odpowiedzialny za zarządzanie i przechowywanie ustawień użytkownika.
/// Używa SharedPreferences do trwałego zapisu.
class SettingsService extends ChangeNotifier {
  // Domyślne wartości ustawień, jeśli nie ma ich w SharedPreferences.
  GlucoseUnit _currentGlucoseUnit = GlucoseUnit.mgDl;
  double _lowGlucoseThresholdMgDl = 70.0; // Przechowujemy progi zawsze w mg/dL
  double _highGlucoseThresholdMgDl = 180.0; // dla spójności i łatwości konwersji.

  /// Zwraca aktualnie wybraną jednostkę glikemii.
  GlucoseUnit get currentGlucoseUnit => _currentGlucoseUnit;

  /// Zwraca próg niskiej glikemii w aktualnie wybranej jednostce.
  double get lowGlucoseThreshold {
    return _convertValue(_lowGlucoseThresholdMgDl, _currentGlucoseUnit);
  }

  /// Zwraca próg wysokiej glikemii w aktualnie wybranej jednostce.
  double get highGlucoseThreshold {
    return _convertValue(_highGlucoseThresholdMgDl, _currentGlucoseUnit);
  }

  // --- NOWE GETTERY ---
  /// Zwraca próg niskiej glikemii zawsze w mg/dL (dla wewnętrznych obliczeń np. w NightscoutDataService).
  double get lowGlucoseThresholdMgDl => _lowGlucoseThresholdMgDl;

  /// Zwraca próg wysokiej glikemii zawsze w mg/dL (dla wewnętrznych obliczeń np. w NightscoutDataService).
  double get highGlucoseThresholdMgDl => _highGlucoseThresholdMgDl;
  // --- KONIEC NOWYCH GETTERÓW ---


  /// Konstruktor serwisu. Ładuje ustawienia przy inicjalizacji.
  SettingsService() {
    _loadSettings();
  }

  /// Ustawia nową jednostkę glikemii i zapisuje ją.
  Future<void> setGlucoseUnit(GlucoseUnit unit) async {
    if (_currentGlucoseUnit != unit) {
      _currentGlucoseUnit = unit;
      await _saveSettings();
      notifyListeners(); // Powiadom wszystkich słuchaczy o zmianie
    }
  }

  /// Ustawia nowy próg niskiej glikemii i zapisuje go.
  /// Wartość wejściowa `threshold` jest w jednostkach podanych przez `unit`.
  Future<void> setLowGlucoseThreshold(double threshold, GlucoseUnit unit) async {
    // Konwertujemy wejściową wartość progu do mg/dL, aby zawsze przechowywać w tej jednostce.
    double thresholdMgDl = _convertToMgDl(threshold, unit);
    if (_lowGlucoseThresholdMgDl != thresholdMgDl) {
      _lowGlucoseThresholdMgDl = thresholdMgDl;
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Ustawia nowy próg wysokiej glikemii i zapisuje go.
  /// Wartość wejściowa `threshold` jest w jednostkach podanych przez `unit`.
  Future<void> setHighGlucoseThreshold(double threshold, GlucoseUnit unit) async {
    // Konwertujemy wejściową wartość progu do mg/dL, aby zawsze przechowywać w tej jednostce.
    double thresholdMgDl = _convertToMgDl(threshold, unit);
    if (_highGlucoseThresholdMgDl != thresholdMgDl) {
      _highGlucoseThresholdMgDl = thresholdMgDl;
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Ładuje ustawienia z SharedPreferences.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Pobierz jednostkę glikemii
    final String? unitString = prefs.getString('glucoseUnit');
    if (unitString != null) {
      try {
        // Przekształć string z powrotem na wartość enum
        _currentGlucoseUnit = GlucoseUnit.values.firstWhere((e) => e.toString() == 'GlucoseUnit.$unitString');
      } catch (e) {
        // W przypadku błędu (np. nieznanej wartości), użyj domyślnej
        _currentGlucoseUnit = GlucoseUnit.mgDl;
      }
    }

    // Pobierz progi glikemii (domyślnie 70.0 i 180.0 mg/dL)
    _lowGlucoseThresholdMgDl = prefs.getDouble('lowGlucoseThresholdMgDl') ?? 70.0;
    _highGlucoseThresholdMgDl = prefs.getDouble('highGlucoseThresholdMgDl') ?? 180.0;

    notifyListeners(); // Powiadom o załadowaniu ustawień
  }

  /// Zapisuje bieżące ustawienia do SharedPreferences.
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Zapisz nazwę enuma (np. 'mgDl', 'mmolL')
    await prefs.setString('glucoseUnit', _currentGlucoseUnit.name);
    await prefs.setDouble('lowGlucoseThresholdMgDl', _lowGlucoseThresholdMgDl);
    await prefs.setDouble('highGlucoseThresholdMgDl', _highGlucoseThresholdMgDl);
  }

  /// Współczynnik konwersji: 1 mmol/L = 18.0157 mg/dL.
  static const double _mgDlToMmolLConversionFactor = 18.0157;

  /// Konwertuje wartość glikemii z mg/dL na wskazaną jednostkę docelową.
  /// Służy do wyświetlania wartości w UI.
  double _convertValue(double valueMgDl, GlucoseUnit targetUnit) {
    if (targetUnit == GlucoseUnit.mgDl) {
      return valueMgDl; // Wartość jest już w mg/dL
    } else { // Konwertuj z mg/dL na mmol/L
      return valueMgDl / _mgDlToMmolLConversionFactor;
    }
  }

  /// Konwertuje wartość glikemii z jednostki źródłowej na mg/dL.
  /// Służy do wewnętrznego przechowywania wszystkich progów w mg/dL.
  double _convertToMgDl(double value, GlucoseUnit sourceUnit) {
    if (sourceUnit == GlucoseUnit.mgDl) {
      return value;
    } else { // Konwertuj z mmol/L na mg/dL
      return value * _mgDlToMmolLConversionFactor;
    }
  }

  /// Publiczna metoda do konwersji wartości SGV (zawsze w mg/dL z Nightscout)
  /// na aktualnie wybraną jednostkę w aplikacji.
  double convertSgvToCurrentUnit(double sgvValueMgDl) {
    return _convertValue(sgvValueMgDl, _currentGlucoseUnit);
  }
}