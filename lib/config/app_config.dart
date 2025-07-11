// lib/config/app_config.dart

/// Klasa zawierająca globalne stałe konfiguracyjne dla aplikacji.
class AppConfig {
  /// Bazowy URL API Nightscout.
  /// ZMIEŃ NA SWÓJ WŁASNY ADRES URL NIGHTSCOUT API.
  static const String nightscoutApiBaseUrl = 'https://web-production-6e2e.up.railway.app'; // <--- WPROWADŹ SWÓJ ADRES TUTAJ

  /// Domyślny czas odświeżania danych z Nightscout.
  static const Duration refreshDuration = Duration(minutes: 1);

  // UWAGA: Progi glikemii oraz API Secret zostały usunięte z tego pliku.
  // Progi są teraz zarządzane dynamicznie przez SettingsService
  // dla większej elastyczności i możliwości zapisu przez użytkownika.
  // API Secret nie jest potrzebny do odczytu publicznych danych,
  // a jego przechowywanie w kodzie jest niebezpieczne.
}