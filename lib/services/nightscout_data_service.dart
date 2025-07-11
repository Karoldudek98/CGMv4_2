// lib/services/nightscout_data_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgmv4/config/app_config.dart';
import 'package:cgmv4/models/sgv_entry.dart';
import 'package:cgmv4/models/cgm_alert.dart';
import 'package:cgmv4/services/settings_service.dart'; // Import SettingsService

/// Serwis do pobierania danych glikemii z Nightscout API i zarządzania alertami.
class NightscoutDataService extends ChangeNotifier with WidgetsBindingObserver {
  SgvEntry? _latestSgv;
  SgvEntry? _previousSgv;
  double? _glucoseDelta;
  bool _isLoading = false;
  String? _errorMessage;
  List<CgmAlert> _alerts = [];
  
  DateTime? _lastProcessedSgvTimestamp; // Timestamp ostatniego przetworzonego SGV dla unikania duplikatów alertów

  Timer? _refreshTimer; // Timer do cyklicznego odświeżania danych

  final SettingsService _settingsService; // Referencja do SettingsService

  // Gettery do dostępu do danych
  SgvEntry? get latestSgv => _latestSgv;
  double? get glucoseDelta => _glucoseDelta;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CgmAlert> get alerts => _alerts;

  // Czy są nieprzeczytane alerty
  bool get hasUnreadAlerts => _alerts.any((alert) => !alert.isRead);

  /// Konstruktor serwisu. Wymaga instancji SettingsService.
  NightscoutDataService(this._settingsService) {
    WidgetsBinding.instance.addObserver(this);
    // Nasłuchuj zmian w SettingsService, aby reagować na zmiany progów glikemii.
    _settingsService.addListener(_onSettingsChanged);
    
    _loadAlerts().then((_) {
      // Po załadowaniu alertów, ustaw timestamp ostatnio przetworzonego SGV,
      // aby uniknąć ponownego generowania alertów dla tych samych danych po restarcie.
      if (_alerts.isNotEmpty) {
        _lastProcessedSgvTimestamp = _alerts.first.timestamp;
      }
      fetchNightscoutData(); // Pierwsze pobranie danych
      _startRefreshTimer(); // Uruchomienie timera odświeżania
    });
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged); // Usuń nasłuchiwanie
    _stopRefreshTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reaguj na zmiany stanu cyklu życia aplikacji (np. wznowienie z tła)
    if (state == AppLifecycleState.resumed) {
      fetchNightscoutData();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopRefreshTimer();
    }
  }

  /// Reaguje na zmiany w SettingsService (np. zmianę progów lub jednostek).
  void _onSettingsChanged() {
    // Kiedy ustawienia się zmienią, warto ponownie sprawdzić aktualne dane
    // i ewentualnie wygenerować/zaktualizować alerty.
    fetchNightscoutData();
  }

  /// Rozpoczyna timer do cyklicznego odświeżania danych.
  void _startRefreshTimer() {
    _refreshTimer?.cancel(); // Anuluj poprzedni timer, jeśli istnieje
    _refreshTimer = Timer.periodic(AppConfig.refreshDuration, (timer) {
      fetchNightscoutData(); // Cyklicznie pobieraj dane
    });
  }

  /// Zatrzymuje timer odświeżania danych.
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Pobiera najnowsze dane glikemii z Nightscout API.
  Future<void> fetchNightscoutData() async {
    if (_isLoading) return; // Zapobiegaj wielokrotnym zapytaniom

    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Powiadom słuchaczy o rozpoczęciu ładowania

    try {
      // Pobieramy 2 ostatnie wpisy do obliczenia delty i bieżącego SGV.
      // Domyślnie Nightscout zwraca dane w mg/dL.
      final url = Uri.parse('${AppConfig.nightscoutApiBaseUrl}/api/v1/entries.json?count=2');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final SgvEntry currentSgv = SgvEntry.fromJson(data[0]);

          // Kluczowa logika zapobiegania dublowaniu alertów dla tego samego (już przetworzonego) czasu odczytu.
          // Sprawdzamy, czy nowe SGV jest "nowsze" niż ostatnie, które przetworzyliśmy pod kątem alertów.
          if (_lastProcessedSgvTimestamp != null && 
              !currentSgv.date.isAfter(_lastProcessedSgvTimestamp!)) {
            _isLoading = false;
            // Jeśli dane nie są nowsze, nie ma potrzeby dalszego przetwarzania alertów.
            return;
          }

          _previousSgv = _latestSgv;
          _latestSgv = currentSgv;
          // Aktualizujemy czas ostatnio przetworzonego odczytu na czas właśnie przetworzonego SGV.
          _lastProcessedSgvTimestamp = _latestSgv!.date; 

          if (_previousSgv != null) {
            _glucoseDelta = _latestSgv!.sgv - _previousSgv!.sgv;
          } else {
            _glucoseDelta = 0.0;
          }

          // Generujemy alert tylko dla *nowego* odczytu SGV.
          _checkAndGenerateAlerts(_latestSgv!);
        } else {
          _errorMessage = 'Brak danych w odpowiedzi z Nightscout.';
        }
      } else {
        _errorMessage = 'Błąd serwera Nightscout: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Błąd połączenia: $e';
    } finally {
      _isLoading = false;
      notifyListeners(); // Powiadom słuchaczy o zakończeniu ładowania (z sukcesem lub błędem)
    }
  }

  /// Pobiera historyczne dane glikemii dla wykresu z Nightscout API.
  /// Dane zawsze są zwracane w mg/dL z API.
  Future<List<SgvEntry>> fetchHistoricalData(Duration range) async {
    // Obliczamy liczbę wpisów, aby pokryć dany zakres czasu (Nightscout domyślnie co 5 minut).
    // Dodajemy mały bufor (+10), aby mieć pewność, że pokryjemy cały zakres.
    final int count = (range.inMinutes / 5).ceil() + 10; 
    
    final url = Uri.parse('${AppConfig.nightscoutApiBaseUrl}/api/v1/entries.json?count=$count');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Filtrujemy dane, aby tylko te, które są w wybranym zakresie czasowym, zostały zwrócone.
        final DateTime startTime = DateTime.now().subtract(range);
        return data
            .map((json) => SgvEntry.fromJson(json))
            .where((entry) => entry.date.isAfter(startTime))
            .toList();
      } else {
        throw Exception('Failed to load historical data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect or parse historical data: $e');
    }
  }

  /// Sprawdza, czy bieżący odczyt SGV wygenerował alert, i dodaje go do listy.
  void _checkAndGenerateAlerts(SgvEntry sgvEntry) {
    String? alertMessage;
    Color? alertColor;
    String? alertType;

    // Pobieramy aktualne progi glikemii z SettingsService.
    // Te progi są już przekonwertowane do mg/dL (ponieważ sgvEntry.sgv jest w mg/dL).
    final double highThreshold = _settingsService.highGlucoseThresholdMgDl; // Użyj wartości przechowywanych w mg/dL
    final double lowThreshold = _settingsService.lowGlucoseThresholdMgDl;   // Użyj wartości przechowywanych w mg/dL
    
    // Konwertujemy wartość SGV odczytu na aktualnie wybraną jednostkę wyświetlania,
    // aby komunikat alertu był zgodny z jednostkami użytkownika.
    final double sgvValueInCurrentUnit = _settingsService.convertSgvToCurrentUnit(sgvEntry.sgv);
    final String unitText = _settingsService.currentGlucoseUnit.name; // Nazwa jednostki (mgDl/mmolL)

    // Sprawdzamy alerty na podstawie wartości SGV w mg/dL (czyli oryginalnej wartości z Nightscout)
    if (sgvEntry.sgv > highThreshold) {
      alertMessage = 'Wysoka glikemia: ${sgvValueInCurrentUnit.toStringAsFixed(unitText == 'mgDl' ? 0 : 1)} $unitText';
      alertColor = Colors.red;
      alertType = "HIGH";
    } else if (sgvEntry.sgv < lowThreshold) {
      alertMessage = 'Niska glikemia: ${sgvValueInCurrentUnit.toStringAsFixed(unitText == 'mgDl' ? 0 : 1)} $unitText';
      alertColor = Colors.orange;
      alertType = "LOW";
    }

    if (alertMessage != null) {
      _alerts.insert(0, CgmAlert( // Dodaj alert na początek listy
        message: alertMessage,
        timestamp: sgvEntry.date,
        type: alertType!,
        alertColor: alertColor!,
      ));
    }
    _saveAlerts(); // Zapisz alerty po każdej zmianie (na przyszłość)
  }

  /// Oznacza wszystkie alerty jako przeczytane.
  void markAllAlertsAsRead() {
    for (var alert in _alerts) {
      alert.isRead = true;
    }
    notifyListeners();
    _saveAlerts(); // Zapisz zmiany
  }

  /// Zapisuje aktualną listę alertów do SharedPreferences (na przyszłość, aby były trwałe).
  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> alertsJson = _alerts.map((alert) => json.encode(alert.toJson())).toList();
    await prefs.setStringList('cgm_alerts', alertsJson);
  }

  /// Ładuje alerty z SharedPreferences (na przyszłość, aby były trwałe po restarcie).
  Future<void> _loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? alertsJson = prefs.getStringList('cgm_alerts');
    if (alertsJson != null) {
      _alerts = alertsJson.map((jsonString) => CgmAlert.fromJson(json.decode(jsonString))).toList();
    }
    // Ustaw _lastProcessedSgvTimestamp po załadowaniu alertów,
    // aby uniknąć duplikatów przy restarcie aplikacji.
    if (_alerts.isNotEmpty) {
      _lastProcessedSgvTimestamp = _alerts.first.timestamp;
    }
    notifyListeners();
  }
}