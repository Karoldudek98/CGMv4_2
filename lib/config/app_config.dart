// lib/config/app_config.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // --- ZASZYTE NA STAŁE W KODZIE URL i API SECRET ---
  // Użytkownik nie ma możliwości ich zmiany.
  // PAMIĘTAJ: ZASTĄP PONIŻSZE WARTOŚCI SWOIMI PRAWDZIWYMI DANE NIGHTSCOUT!
  static const String _nightscoutUrl = 'https://web-production-6e2e.up.railway.app/'; // ZMIEŃ TO!
  static const String _apiSecret = 'Mojesilnehaslo123'; // ZMIEŃ TO!
  // ----------------------------------------------------

  // Stała dla interwału odświeżania danych SGV (dla Home Screen)
  static const Duration refreshDuration = Duration(minutes: 1);

  // --- STAŁE WYMAGANE PRZEZ CHART_SCREEN.DART ---
  // Liczba punktów danych dla wykresu (24h * 60min = 1440 punktów)
  static const int chartDataPoints = 1440;
  // Próg wysokiej glikemii (mg/dL) - linia referencyjna na wykresie i dla alertów
  static const double highGlucoseThreshold = 180.0;
  // Próg niskiej glikemii (mg/dL) - linia referencyjna na wykresie i dla alertów
  static const double lowGlucoseThreshold = 70.0;
  // --- KONIEC STAŁYCH WYMAGANYCH PRZEZ CHART_SCREEN.DART ---

  // Gettery do odczytu stałych wartości
  static String get nightscoutUrl => _nightscoutUrl;
  static String get apiSecret => _apiSecret;

  // PRZYSZŁE ZMIENNE USTAWIENIA (nie są jeszcze używane)
  static const String _glucoseUnitKey = 'glucoseUnit';
  static const String _timeOffsetKey = 'timeOffsetHours';

  static String _currentGlucoseUnit = 'mg/dL'; // Domyślna jednostka
  static int _currentTimeOffsetHours = 0; // Domyślne przesunięcie czasowe

  static String get currentGlucoseUnit => _currentGlucoseUnit;
  static int get currentTimeOffsetHours => _currentTimeOffsetHours;

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _currentGlucoseUnit = prefs.getString(_glucoseUnitKey) ?? 'mg/dL';
    _currentTimeOffsetHours = prefs.getInt(_timeOffsetKey) ?? 0;
  }

  static Future<void> setGlucoseUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    _currentGlucoseUnit = unit;
    await prefs.setString(_glucoseUnitKey, unit);
  }

  static Future<void> setTimeOffsetHours(int offset) async {
    final prefs = await SharedPreferences.getInstance();
    _currentTimeOffsetHours = offset;
    await prefs.setInt(_timeOffsetKey, offset);
  }
}