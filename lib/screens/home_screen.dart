// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/services/settings_service.dart';
import 'package:cgmv4/models/glucose_unit.dart';

/// Ekran główny wyświetlający aktualną wartość glikemii i powiązane informacje.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<NightscoutDataService>(context, listen: false).fetchNightscoutData();
    }
  }

  /// Mapuje tekstowy kierunek glikemii na symbol strzałki Unicode.
  String _mapDirectionToArrow(String direction) {
    switch (direction.toLowerCase()) {
      case 'doubleup':
        return '⇈'; // Podwójny wzrost
      case 'singleup':
        return '↑'; // Pojedynczy wzrost
      case 'fortyfiveup':
        return '↗'; // Wzrost pod kątem 45 stopni
      case 'flat':
        return '→'; // Płasko
      case 'fortyfivedown':
        return '↘'; // Spadek pod kątem 45 stopni
      case 'singledown':
        return '↓'; // Pojedynczy spadek
      case 'doubledown':
        return '⇊'; // Podwójny spadek
      case 'not computable':
      case 'none':
      case 'unknown':
      default:
        return ''; // Brak symbolu dla nieznanych
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktualna Glikemia'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<NightscoutDataService>(context, listen: false).fetchNightscoutData();
            },
          ),
        ],
      ),
      body: Consumer2<NightscoutDataService, SettingsService>(
        builder: (context, nightscoutService, settingsService, child) {
          if (nightscoutService.isLoading && nightscoutService.latestSgv == null) {
            // Wyświetlaj CircularProgressIndicator tylko, gdy nic nie ma i trwa ładowanie
            return const Center(child: CircularProgressIndicator());
          } else if (nightscoutService.errorMessage != null && nightscoutService.latestSgv == null) {
            // Wyświetlaj błąd tylko, gdy nic nie ma i jest błąd
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'Błąd: ${nightscoutService.errorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        nightscoutService.fetchNightscoutData();
                      },
                      child: const Text('Spróbuj ponownie'),
                    ),
                  ],
                ),
              ),
            );
          } else if (nightscoutService.latestSgv == null) {
            // Gdy nie ma danych i nie ma błędu ładowania (np. po restarcie przed pierwszym pobraniem)
            // Uruchomienie fetchNightscoutData() w initState powinno to obsłużyć,
            // ale ten stan może wystąpić, jeśli Nightscout jest pusty.
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 80),
                    SizedBox(height: 20),
                    Text(
                      'Brak danych SGV. Upewnij się, że Nightscout działa i ma dane.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Mamy dane SGV do wyświetlenia
            final sgvEntry = nightscoutService.latestSgv!;
            final glucoseUnit = settingsService.currentGlucoseUnit;

            final double displaySgv = settingsService.convertSgvToCurrentUnit(sgvEntry.sgv);
            final String unitText = glucoseUnit == GlucoseUnit.mgDl ? 'mg/dL' : 'mmol/L';

            String deltaText = '';
            if (nightscoutService.glucoseDelta != null) {
              final double displayDelta = settingsService.convertSgvToCurrentUnit(nightscoutService.glucoseDelta!);
              if (displayDelta != 0.0) { // Tylko jeśli delta nie jest zerowa
                // Formatowanie delty: znak i zaokrąglenie
                deltaText = ' (${displayDelta > 0 ? '+' : ''}${displayDelta.toStringAsFixed(glucoseUnit == GlucoseUnit.mgDl ? 0 : 1)})';
              }
            }
            
            // Kolor tła w zależności od wartości SGV względem progów.
            final double lowThreshold = settingsService.lowGlucoseThreshold;
            final double highThreshold = settingsService.highGlucoseThreshold;
            Color backgroundColor;
            if (displaySgv < lowThreshold) {
              backgroundColor = Colors.orange.shade100;
            } else if (displaySgv > highThreshold) {
              backgroundColor = Colors.red.shade100;
            } else {
              backgroundColor = Colors.green.shade100;
            }

            return Container(
              color: backgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Ostatni odczyt ($unitText):',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline, // Wyrównanie linii bazowej tekstu
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _mapDirectionToArrow(sgvEntry.direction), // Strzałka kierunku
                          style: const TextStyle(fontSize: 50, color: Colors.black54),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          displaySgv.toStringAsFixed(glucoseUnit == GlucoseUnit.mgDl ? 0 : 1),
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: displaySgv < lowThreshold || displaySgv > highThreshold ? Colors.red : Colors.black,
                          ),
                        ),
                        if (deltaText.isNotEmpty) // Wyświetlaj deltę tylko, jeśli nie jest pusta
                          Text(
                            deltaText,
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.normal, color: Colors.black54),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ostatnie odświeżenie: ${DateFormat('HH:mm:ss').format(sgvEntry.date.toLocal())}',
                      style: const TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}