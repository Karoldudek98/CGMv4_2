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


class NightscoutDataService extends ChangeNotifier with WidgetsBindingObserver {
  SgvEntry? _latestSgv;
  SgvEntry? _previousSgv;
  double? _glucoseDelta;
  bool _isLoading = false;
  String? _errorMessage;
  List<CgmAlert> _alerts = [];
  
  DateTime? _lastProcessedSgvTimestamp;
  
  static const Duration _dismissDuration = Duration(minutes: 15); 

  Timer? _refreshTimer;

  final SettingsService _settingsService;

  SgvEntry? get latestSgv => _latestSgv;
  double? get glucoseDelta => _glucoseDelta;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CgmAlert> get activeAlerts => _alerts.where((alert) => alert.isActive).toList();

  bool get hasUnreadAlerts => activeAlerts.any((alert) => !alert.isRead);

  NightscoutDataService(this._settingsService) {
    WidgetsBinding.instance.addObserver(this);
    _settingsService.addListener(_onSettingsChanged);
    
    _loadAlerts().then((_) {
      _cleanupOldDismissedAlerts();
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
      fetchNightscoutData();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopRefreshTimer();
    }
  }

  void _onSettingsChanged() {
    if (_latestSgv != null) {
      _checkAndGenerateAlerts(_latestSgv!);
    }
    notifyListeners();
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

  Future<void> fetchNightscoutData() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;

    try {
      final url = Uri.parse('${AppConfig.nightscoutApiBaseUrl}/api/v1/entries.json?count=2');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final SgvEntry newLatestSgv = SgvEntry.fromJson(data[0]);

          if (_latestSgv == null || newLatestSgv.date.isAfter(_latestSgv!.date)) {
            _previousSgv = _latestSgv;
            _latestSgv = newLatestSgv;

            if (data.length >= 2) {
              final SgvEntry potentialPreviousSgv = SgvEntry.fromJson(data[1]);
              _glucoseDelta = _latestSgv!.sgv - potentialPreviousSgv.sgv;
            } else {
              _glucoseDelta = null;
            }

            if (_lastProcessedSgvTimestamp == null || _latestSgv!.date.isAfter(_lastProcessedSgvTimestamp!)) {
                _checkAndGenerateAlerts(_latestSgv!);
                _lastProcessedSgvTimestamp = _latestSgv!.date;
            }
          } else {
            _checkAndGenerateAlerts(_latestSgv!);
          }
        } else {
          _errorMessage = 'Brak danych w odpowiedzi z Nightscout.';
          _latestSgv = null;
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
      _cleanupOldDismissedAlerts();
      notifyListeners();
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
      alertColor = Colors.orange;
      alertType = "HIGH";
    } else if (sgvEntry.sgv < lowThreshold) {
      alertMessage = 'Niska glikemia: ${sgvValueInCurrentUnit.toStringAsFixed(unitText == 'mgDl' ? 0 : 1)} $unitText';
      alertColor = Colors.red;
      alertType = "LOW";
    }

    if (alertMessage != null) {
      bool alertExists = _alerts.any((alert) => 
        alert.timestamp == sgvEntry.date && 
        alert.type == alertType
      );

      if (alertExists) {
        return;
      }

      _alerts.insert(0, CgmAlert(
        message: alertMessage,
        timestamp: sgvEntry.date,
        type: alertType!,
        alertColor: alertColor!,
      ));
      _saveAlerts();
    }
  }

  void markAllAlertsAsRead() {
    for (var alert in _alerts) {
      alert.isRead = true;
    }
    notifyListeners();
    _saveAlerts();
  }

  void dismissAlert(CgmAlert alert) {
    final int index = _alerts.indexOf(alert);
    if (index != -1) {
      _alerts[index] = CgmAlert(
        message: alert.message,
        timestamp: alert.timestamp,
        type: alert.type,
        alertColor: alert.alertColor,
        isRead: true, 
        dismissedUntil: DateTime.now().add(_dismissDuration),
      );
      notifyListeners();
      _saveAlerts();
    }
  }

  void _cleanupOldDismissedAlerts() {
    final int initialCount = _alerts.length;
    _alerts.removeWhere((alert) => alert.dismissedUntil != null && alert.dismissedUntil!.isBefore(DateTime.now()));
    if (_alerts.length != initialCount) {
      _saveAlerts();
    }
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
    if (_alerts.isNotEmpty) {
      _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _lastProcessedSgvTimestamp = _alerts.first.timestamp;
    }
    notifyListeners();
  }
}