// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/services/settings_service.dart'; // Import SettingsService
import 'package:cgmv4/models/glucose_unit.dart'; // Import GlucoseUnit

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
    // Przy wznowieniu aplikacji z tła, wymuś odświeżenie danych.
    if (state == AppLifecycleState.resumed) {
      Provider.of<NightscoutDataService>(context, listen: false).fetchNightscoutData();
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
      // Używamy Consumer2, aby nasłuchiwać zmian zarówno w NightscoutDataService, jak i SettingsService.
      body: Consumer2<NightscoutDataService, SettingsService>(
        builder: (context, nightscoutService, settingsService, child) {
          if (nightscoutService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (nightscoutService.errorMessage != null) {
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
            final sgvEntry = nightscoutService.latestSgv!;
            final glucoseUnit = settingsService.currentGlucoseUnit;

            // Konwersja wartości SGV na wybraną jednostkę do wyświetlenia.
            final double displaySgv = settingsService.convertSgvToCurrentUnit(sgvEntry.sgv);
            final String unitText = glucoseUnit == GlucoseUnit.mgDl ? 'mg/dL' : 'mmol/L';

            // Obliczenie delty w odpowiedniej jednostce.
            double? displayDelta;
            if (nightscoutService.glucoseDelta != null) {
              // Delta też musi być skonwertowana, ale operujemy na wartości bezwzględnej dla wyświetlania.
              displayDelta = settingsService.convertSgvToCurrentUnit(nightscoutService.glucoseDelta!.abs());
            }

            // Pobranie progów alertów w odpowiedniej jednostce do wizualizacji tła.
            final double lowThreshold = settingsService.lowGlucoseThreshold;
            final double highThreshold = settingsService.highGlucoseThreshold;

            // Ustalenie koloru tła w zależności od wartości SGV względem progów.
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
                    Text(
                      // Formatowanie liczby dziesiętnej w zależności od jednostki (0 miejsc dla mg/dL, 1 dla mmol/L)
                      displaySgv.toStringAsFixed(glucoseUnit == GlucoseUnit.mgDl ? 0 : 1),
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        // Kolor tekstu dla wartości poza zakresem.
                        color: displaySgv < lowThreshold || displaySgv > highThreshold ? Colors.red : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (nightscoutService.glucoseDelta != null)
                      Text(
                        // Wyświetlanie delty ze znakiem i w odpowiednich jednostkach.
                        'Zmiana: ${nightscoutService.glucoseDelta! > 0 ? '+' : ''}${displayDelta!.toStringAsFixed(glucoseUnit == GlucoseUnit.mgDl ? 0 : 1)} $unitText',
                        style: const TextStyle(fontSize: 28),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'Kierunek: ${sgvEntry.direction}',
                      style: const TextStyle(fontSize: 24),
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