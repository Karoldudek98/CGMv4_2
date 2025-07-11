// lib/services/nightscout_data_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cgmv4/config/app_config.dart';
import 'package:cgmv4/models/cgm_alert.dart';
import 'package:intl/intl.dart'; // Nadal przydatne, ale nie do formatowania URL

class SgvEntry {
  final double sgv;
  final DateTime date;
  final int trend;

  SgvEntry({required this.sgv, required this.date, required this.trend});

  factory SgvEntry.fromJson(Map<String, dynamic> json) {
    DateTime entryDate;
    if (json['dateString'] != null) {
      entryDate = DateTime.parse(json['dateString'] as String);
    } else if (json['date'] != null) {
      entryDate = DateTime.fromMillisecondsSinceEpoch(json['date'] as int);
    } else {
      entryDate = DateTime.now(); // Fallback
    }

    return SgvEntry(
      sgv: (json['sgv'] as num).toDouble(),
      date: entryDate,
      trend: (json['trend'] as num?)?.toInt() ?? 0,
    );
  }
}

class NightscoutDataService extends ChangeNotifier with WidgetsBindingObserver {
  SgvEntry? _latestSgv;
  bool _isLoading = false;
  Timer? _refreshTimer;

  final List<CgmAlert> _alerts = [];
  static const double _highGlucoseThreshold = 180.0;
  static const double _lowGlucoseThreshold = 70.0;
  static const Duration _signalLossThreshold = Duration(minutes: 15);

  SgvEntry? get latestSgv => _latestSgv;
  bool get isLoading => _isLoading;
  List<CgmAlert> get alerts => List.unmodifiable(_alerts);
  bool get hasUnreadAlerts => _alerts.any((alert) => !alert.isRead);

  NightscoutDataService() {
    WidgetsBinding.instance.addObserver(this);
    fetchNightscoutData();
    _startRefreshTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchNightscoutData();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopRefreshTimer();
    }
  }

  void markAllAlertsAsRead() {
    if (_alerts.any((alert) => !alert.isRead)) {
      for (var alert in _alerts) {
        alert.markAsRead();
      }
      notifyListeners();
    }
  }

  Future<void> fetchNightscoutData() async {
    if (_isLoading) {
      print('fetchNightscoutData: Already loading, skipping this request.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final nightscoutBaseUrl = AppConfig.nightscoutUrl;
      final apiSecret = AppConfig.apiSecret;

      if (nightscoutBaseUrl.isEmpty || apiSecret.isEmpty ||
          nightscoutBaseUrl == 'https://YOUR_NIGHTSCOUT_URL.herokuapp.com/' ||
          apiSecret == 'YOUR_API_SECRET') {
        _addAlertIfNeeded(CgmAlert(
          type: AlertType.signalLoss,
          timestamp: DateTime.now(),
          message: 'Błąd konfiguracji: Nightscout URL lub API Secret nie ustawione! Skontaktuj się z deweloperem.',
        ));
        _latestSgv = null;
        return;
      }

      final String fullApiUrl = '${nightscoutBaseUrl}api/v1/entries/sgv.json?count=1&token=$apiSecret';

      print('Attempting to fetch data from URL: $fullApiUrl');

      final response = await http.get(
        Uri.parse(fullApiUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('HTTP 200 OK. Response body length: ${response.body.length}');
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          _latestSgv = SgvEntry.fromJson(data[0]);
          _checkGlucoseAlerts(_latestSgv!);
          _checkSignalLossAlert(_latestSgv!.date);
        } else {
          _latestSgv = null;
          _checkSignalLossAlert(null);
          _addAlertIfNeeded(CgmAlert(
            type: AlertType.signalLoss,
            timestamp: DateTime.now(),
            message: 'Nightscout zwrócił puste dane. Brak odczytów.',
          ));
          print('Nightscout returned empty data.');
        }
      } else {
        _latestSgv = null;
        _addAlertIfNeeded(CgmAlert(
          type: AlertType.signalLoss,
          timestamp: DateTime.now(),
          message: 'Błąd HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Nieznany błąd'}',
        ));
        print('HTTP Error: ${response.statusCode}. Reason: ${response.reasonPhrase}. Body: ${response.body}');
      }
    } on TimeoutException {
      _latestSgv = null;
      _addAlertIfNeeded(CgmAlert(
        type: AlertType.signalLoss,
        timestamp: DateTime.now(),
        message: 'Timeout połączenia z Nightscout. Sprawdź połączenie.',
      ));
      print('TimeoutException: Could not connect to Nightscout.');
    } catch (e) {
      _latestSgv = null;
      _addAlertIfNeeded(CgmAlert(
        type: AlertType.signalLoss,
        timestamp: DateTime.now(),
        message: 'Wystąpił nieoczekiwany błąd: ${e.toString()}',
      ));
      print('Unexpected error in fetchNightscoutData: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _checkGlucoseAlerts(SgvEntry sgvEntry) {
    if (sgvEntry.sgv > _highGlucoseThreshold) {
      _addAlertIfNeeded(CgmAlert(
        type: AlertType.highGlucose,
        timestamp: sgvEntry.date,
        glucoseValue: sgvEntry.sgv,
        message: 'Wysoka glikemia: ${sgvEntry.sgv.toInt()} mg/dL',
      ));
    } else if (sgvEntry.sgv < _lowGlucoseThreshold) {
      _addAlertIfNeeded(CgmAlert(
        type: AlertType.lowGlucose,
        timestamp: sgvEntry.date,
        glucoseValue: sgvEntry.sgv,
        message: 'Niska glikemia: ${sgvEntry.sgv.toInt()} mg/dL',
      ));
    } else {
      _removeActiveAlertsOfType(AlertType.highGlucose);
      _removeActiveAlertsOfType(AlertType.lowGlucose);
    }
  }

  void _checkSignalLossAlert(DateTime? lastSgvDate) {
    if (AppConfig.nightscoutUrl.isEmpty || AppConfig.apiSecret.isEmpty || AppConfig.nightscoutUrl == 'https://YOUR_NIGHTSCOUT_URL.herokuapp.com/' || AppConfig.apiSecret == 'YOUR_API_SECRET') {
      return;
    }

    final now = DateTime.now();
    if (lastSgvDate == null || now.difference(lastSgvDate) > _signalLossThreshold) {
      _addAlertIfNeeded(CgmAlert(
        type: AlertType.signalLoss,
        timestamp: now,
        message: 'Utrata sygnału: Brak odczytów przez ${_signalLossThreshold.inMinutes} min.',
      ));
    } else {
      _removeActiveAlertsOfType(AlertType.signalLoss);
    }
  }

  void _addAlertIfNeeded(CgmAlert newAlert) {
    final bool exists = _alerts.any((alert) {
      if (alert.isRead) return false;

      if ((newAlert.type == AlertType.highGlucose || newAlert.type == AlertType.lowGlucose) &&
          alert.type == newAlert.type &&
          (alert.glucoseValue != null && newAlert.glucoseValue != null) &&
          (newAlert.glucoseValue! - alert.glucoseValue!).abs() < 5) {
        return true;
      }
      if (newAlert.type == AlertType.signalLoss && alert.type == AlertType.signalLoss) {
        return true;
      }
      return false;
    });

    if (!exists) {
      _alerts.insert(0, newAlert);
      if (_alerts.length > 30) {
        _alerts.removeLast();
      }
    }
  }

  void _removeActiveAlertsOfType(AlertType type) {
    final int initialLength = _alerts.length;
    _alerts.removeWhere((alert) => alert.type == type && !alert.isRead);
    if (_alerts.length != initialLength) {
      notifyListeners();
    }
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

  @override
  void dispose() {
    _stopRefreshTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ZMIANA: fetchHistoricalData - używamy timestampów w milisekundach
  Future<List<SgvEntry>> fetchHistoricalData(Duration timeRange) async {
    final nightscoutBaseUrl = AppConfig.nightscoutUrl;
    final apiSecret = AppConfig.apiSecret;

    if (nightscoutBaseUrl.isEmpty || apiSecret.isEmpty || nightscoutBaseUrl == 'https://YOUR_NIGHTSCOUT_URL.herokuapp.com/' || apiSecret == 'YOUR_API_SECRET') {
      throw Exception('Nightscout URL lub API Secret nie ustawione. Skontaktuj się z deweloperem.');
    }

    try {
      final now = DateTime.now();
      final startTime = now.subtract(timeRange);

      // KLUCZOWA ZMIANA: Używamy timestampów w milisekundach
      final int startTimeMillis = startTime.millisecondsSinceEpoch;
      final int endTimeMillis = now.millisecondsSinceEpoch;

      // ZMIANA URL: Używamy timestampów w parametrach find[date][$gte] i find[date][$lte]
      // Dodatkowo, dodajemy 'sort$desc=date' aby mieć najnowsze dane na początku (opcjonalnie, ale pomocne)
      // oraz 'count=10000' aby Nightscout zwrócił wszystkie dostępne dane w zakresie.
      final String fullApiUrl = '${nightscoutBaseUrl}api/v1/entries/sgv.json?'
                                'find[date][\$gte]=$startTimeMillis&'
                                'find[date][\$lte]=$endTimeMillis&'
                                'count=10000&'
                                'token=$apiSecret';

      print('Attempting to fetch historical data from URL: $fullApiUrl');

      final response = await http.get(
        Uri.parse(fullApiUrl),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('HTTP 200 OK for historical data. Response body length: ${response.body.length}');
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          print('No historical data found for the given range.');
        }
        return data.map((json) => SgvEntry.fromJson(json)).toList();
      } else {
        print('Failed to load historical data: HTTP Error ${response.statusCode}. Reason: ${response.reasonPhrase}. Body: ${response.body}');
        throw Exception('Failed to load historical data: HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      print('Historical data fetch timed out.');
      throw Exception('Historical data fetch timed out.');
    } catch (e) {
      print('Unexpected error in fetchHistoricalData: $e');
      throw Exception('Failed to load historical data: $e');
    }
  }
}