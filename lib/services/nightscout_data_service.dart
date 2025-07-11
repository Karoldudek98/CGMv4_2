// lib/services/nightscout_data_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgmv4/config/app_config.dart';
import 'package:cgmv4/models/sgv_entry.dart';
import 'package:cgmv4/models/cgm_alert.dart';
import 'package:cgmv4/services/settings_service.dart';

/// Serwis do pobierania danych glikemii z Nightscout API i zarządzania alertami.
class NightscoutDataService extends ChangeNotifier with WidgetsBindingObserver {
  SgvEntry? _latestSgv;
  SgvEntry? _previousSgv;
  double? _glucoseDelta;
  bool _isLoading = false;
  String? _errorMessage;
  List<CgmAlert> _alerts = [];
  
  DateTime? _lastProcessedSgvTimestamp;

  Timer? _refreshTimer;

  final SettingsService _settingsService;

  SgvEntry? get latestSgv => _latestSgv;
  double? get glucoseDelta => _glucoseDelta;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CgmAlert> get alerts => _alerts;

  bool get hasUnreadAlerts => _alerts.any((alert) => !alert.isRead);

  NightscoutDataService(this._settingsService) {
    WidgetsBinding.instance.addObserver(this);
    _settingsService.addListener(_onSettingsChanged);
    
    // Zmieniamy kolejność: najpierw ładujemy alerty (dla _lastProcessedSgvTimestamp),
    // POTEM pobieramy dane Nightscout.
    _loadAlerts().then((_) {
      // Bez względu na to, czy były alerty, próbujemy pobrać dane od razu.
      fetchNightscoutData();
      _startRefreshTimer();
    });
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _stopRefreshTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Po wznowieniu odśwież dane, aby były aktualne
      fetchNightscoutData();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopRefreshTimer();
    }
  }

  void _onSettingsChanged() {
    // Kiedy ustawienia się zmienią, warto ponownie sprawdzić aktualne dane
    // i ewentualnie wygenerować/zaktualizować alerty.
    // Upewnij się, że nie czyści to _lastProcessedSgvTimestamp,
    // aby uniknąć ponownych alertów dla starych danych.
    if (_latestSgv != null) {
      _checkAndGenerateAlerts(_latestSgv!); // Ponownie sprawdz alerty z nowymi progami
    }
    notifyListeners(); // Powiadom o potencjalnych zmianach, np. kolorów na HomeScreen
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(AppConfig.refreshDuration, (timer) {
      fetchNightscoutData();
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Pobiera najnowsze dane glikemii z Nightscout API.
  /// Zawsze próbujemy pobrać co najmniej 2 wpisy, aby obliczyć deltę.
  Future<void> fetchNightscoutData() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    // Nie wywołuj notifyListeners() tutaj, aby uniknąć migotania "Loading"
    // jeśli dane zostaną szybko pobrane i przetworzone.
    // Zostanie wywołane na końcu bloku `finally`.

    try {
      final url = Uri.parse('${AppConfig.nightscoutApiBaseUrl}/api/v1/entries.json?count=2');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final SgvEntry newLatestSgv = SgvEntry.fromJson(data[0]);

          // Sprawdzamy, czy otrzymaliśmy faktycznie nowszy odczyt
          if (_latestSgv == null || newLatestSgv.date.isAfter(_latestSgv!.date)) {
            _previousSgv = _latestSgv; // Aktualne latestSgv staje się poprzednim
            _latestSgv = newLatestSgv; // Nowy odczyt staje się najnowszym

            // Oblicz deltę, jeśli mamy co najmniej dwa odczyty
            if (data.length >= 2) {
              // Upewnij się, że _previousSgv jest aktualne lub pobierz z drugiego elementu listy
              final SgvEntry potentialPreviousSgv = SgvEntry.fromJson(data[1]);
              _glucoseDelta = _latestSgv!.sgv - potentialPreviousSgv.sgv;
            } else {
              _glucoseDelta = null; // Nie ma wystarczających danych do delty
            }

            // Generujemy alert tylko dla *nowego* odczytu SGV, który nie był wcześniej przetworzony.
            if (_lastProcessedSgvTimestamp == null || _latestSgv!.date.isAfter(_lastProcessedSgvTimestamp!)) {
                _checkAndGenerateAlerts(_latestSgv!);
                _lastProcessedSgvTimestamp = _latestSgv!.date; // Aktualizuj timestamp ostatnio przetworzonego
            }
          } else {
            // Dane nie są nowsze, nie aktualizujemy _latestSgv, _previousSgv, ani _glucoseDelta
            // Ale nadal możemy odświeżyć UI, jeśli błędy zniknęły lub coś innego się zmieniło.
            // Sprawdzamy też alerty, bo progi mogły się zmienić
            _checkAndGenerateAlerts(_latestSgv!);
          }
        } else {
          _errorMessage = 'Brak danych w odpowiedzi z Nightscout.';
          _latestSgv = null; // Wyczyść dane, jeśli brak odpowiedzi
          _previousSgv = null;
          _glucoseDelta = null;
        }
      } else {
        _errorMessage = 'Błąd serwera Nightscout: ${response.statusCode}';
        _latestSgv = null;
        _previousSgv = null;
        _glucoseDelta = null;
      }
    } catch (e) {
      _errorMessage = 'Błąd połączenia: $e';
      _latestSgv = null;
      _previousSgv = null;
      _glucoseDelta = null;
    } finally {
      _isLoading = false;
      notifyListeners(); // Powiadom słuchaczy o zakończeniu ładowania (z sukcesem lub błędem)
    }
  }


  Future<List<SgvEntry>> fetchHistoricalData(Duration range) async {
    final int count = (range.inMinutes / 5).ceil() + 10;
    
    final url = Uri.parse('${AppConfig.nightscoutApiBaseUrl}/api/v1/entries.json?count=$count');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
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

  void _checkAndGenerateAlerts(SgvEntry sgvEntry) {
    String? alertMessage;
    Color? alertColor;
    String? alertType;

    final double highThreshold = _settingsService.highGlucoseThresholdMgDl;
    final double lowThreshold = _settingsService.lowGlucoseThresholdMgDl;
    
    final double sgvValueInCurrentUnit = _settingsService.convertSgvToCurrentUnit(sgvEntry.sgv);
    final String unitText = _settingsService.currentGlucoseUnit.name;

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
      // Sprawdzamy, czy ostatni alert tego typu dla tego samego odczytu już istnieje
      // Aby zapobiec duplikatom alertów przy każdym odświeżeniu dla tej samej wartości.
      bool isDuplicate = _alerts.any((alert) => 
        alert.timestamp == sgvEntry.date && 
        alert.type == alertType && 
        alert.message == alertMessage
      );

      if (!isDuplicate) {
        _alerts.insert(0, CgmAlert(
          message: alertMessage,
          timestamp: sgvEntry.date,
          type: alertType!,
          alertColor: alertColor!,
        ));
        _saveAlerts();
      }
    }
  }

  void markAllAlertsAsRead() {
    for (var alert in _alerts) {
      alert.isRead = true;
    }
    notifyListeners();
    _saveAlerts();
  }

  /// Usuwa alert z listy.
  void removeAlert(CgmAlert alert) {
    _alerts.remove(alert);
    notifyListeners();
    _saveAlerts();
  }

  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> alertsJson = _alerts.map((alert) => json.encode(alert.toJson())).toList();
    await prefs.setStringList('cgm_alerts', alertsJson);
  }

  Future<void> _loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? alertsJson = prefs.getStringList('cgm_alerts');
    if (alertsJson != null) {
      _alerts = alertsJson.map((jsonString) => CgmAlert.fromJson(json.decode(jsonString))).toList();
    }
    // Ustaw _lastProcessedSgvTimestamp na najnowszy timestamp z załadowanych alertów,
    // aby uniknąć ponownego generowania alertów dla już przetworzonych danych po restarcie aplikacji.
    if (_alerts.isNotEmpty) {
      _lastProcessedSgvTimestamp = _alerts.first.timestamp;
    }
    notifyListeners();
  }
}