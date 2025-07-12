// lib/services/settings_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cgmv4/models/glucose_unit.dart';


class SettingsService extends ChangeNotifier {
  GlucoseUnit _currentGlucoseUnit = GlucoseUnit.mgDl;
  double _lowGlucoseThresholdMgDl = 70.0;
  double _highGlucoseThresholdMgDl = 180.0;

  GlucoseUnit get currentGlucoseUnit => _currentGlucoseUnit;

  double get lowGlucoseThreshold {
    return _convertValue(_lowGlucoseThresholdMgDl, _currentGlucoseUnit);
  }

  double get highGlucoseThreshold {
    return _convertValue(_highGlucoseThresholdMgDl, _currentGlucoseUnit);
  }

  double get lowGlucoseThresholdMgDl => _lowGlucoseThresholdMgDl;

  double get highGlucoseThresholdMgDl => _highGlucoseThresholdMgDl;



  SettingsService() {
    _loadSettings();
  }


  Future<void> setGlucoseUnit(GlucoseUnit unit) async {
    if (_currentGlucoseUnit != unit) {
      _currentGlucoseUnit = unit;
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setLowGlucoseThreshold(double threshold, GlucoseUnit unit) async {
    double thresholdMgDl = _convertToMgDl(threshold, unit);
    if (_lowGlucoseThresholdMgDl != thresholdMgDl) {
      _lowGlucoseThresholdMgDl = thresholdMgDl;
      await _saveSettings();
      notifyListeners();
    }
  }


  Future<void> setHighGlucoseThreshold(double threshold, GlucoseUnit unit) async {
    double thresholdMgDl = _convertToMgDl(threshold, unit);
    if (_highGlucoseThresholdMgDl != thresholdMgDl) {
      _highGlucoseThresholdMgDl = thresholdMgDl;
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? unitString = prefs.getString('glucoseUnit');
    if (unitString != null) {
      try {
        _currentGlucoseUnit = GlucoseUnit.values.firstWhere((e) => e.toString() == 'GlucoseUnit.$unitString');
      } catch (e) {
        _currentGlucoseUnit = GlucoseUnit.mgDl;
      }
    }

    _lowGlucoseThresholdMgDl = prefs.getDouble('lowGlucoseThresholdMgDl') ?? 70.0;
    _highGlucoseThresholdMgDl = prefs.getDouble('highGlucoseThresholdMgDl') ?? 180.0;

    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('glucoseUnit', _currentGlucoseUnit.name);
    await prefs.setDouble('lowGlucoseThresholdMgDl', _lowGlucoseThresholdMgDl);
    await prefs.setDouble('highGlucoseThresholdMgDl', _highGlucoseThresholdMgDl);
  }

  static const double _mgDlToMmolLConversionFactor = 18.0157;

  double _convertValue(double valueMgDl, GlucoseUnit targetUnit) {
    if (targetUnit == GlucoseUnit.mgDl) {
      return valueMgDl;
    } else {
      return valueMgDl / _mgDlToMmolLConversionFactor;
    }
  }

  double _convertToMgDl(double value, GlucoseUnit sourceUnit) {
    if (sourceUnit == GlucoseUnit.mgDl) {
      return value;
    } else {
      return value * _mgDlToMmolLConversionFactor;
    }
  }

  double convertSgvToCurrentUnit(double sgvValueMgDl) {
    return _convertValue(sgvValueMgDl, _currentGlucoseUnit);
  }
}