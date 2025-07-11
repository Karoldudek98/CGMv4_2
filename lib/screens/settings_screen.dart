// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cgmv4/services/settings_service.dart';
import 'package:cgmv4/models/glucose_unit.dart';

/// Ekran ustawień aplikacji, pozwalający na zmianę jednostek glikemii
/// oraz progów alertów.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Kontrolery do pól tekstowych dla progów glikemii.
  // Umożliwiają edycję i pobieranie wartości z TextField.
  late TextEditingController _lowThresholdController;
  late TextEditingController _highThresholdController;

  @override
  void initState() {
    super.initState();
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    
    // Inicjalizuj kontrolery z aktualnymi wartościami progów pobranymi z SettingsService.
    // Wartości są formatowane do wyświetlenia w odpowiedniej jednostce.
    _lowThresholdController = TextEditingController(
      text: settingsService.lowGlucoseThreshold.toStringAsFixed(
        settingsService.currentGlucoseUnit == GlucoseUnit.mgDl ? 0 : 1,
      ),
    );
    _highThresholdController = TextEditingController(
      text: settingsService.highGlucoseThreshold.toStringAsFixed(
        settingsService.currentGlucoseUnit == GlucoseUnit.mgDl ? 0 : 1,
      ),
    );

    // Dodaj nasłuchiwanie na zmiany w SettingsService.
    // Gdy ustawienia się zmienią (np. jednostka), pola tekstowe zostaną zaktualizowane.
    settingsService.addListener(_updateThresholdControllers);
  }

  @override
  void dispose() {
    // Usuń nasłuchiwanie i zwolnij kontrolery, aby uniknąć wycieków pamięci.
    Provider.of<SettingsService>(context, listen: false).removeListener(_updateThresholdControllers);
    _lowThresholdController.dispose();
    _highThresholdController.dispose();
    super.dispose();
  }

  /// Metoda wywoływana, gdy SettingsService powiadomi o zmianie ustawień.
  /// Aktualizuje pola tekstowe progów, aby odzwierciedlały bieżące wartości i jednostki.
  void _updateThresholdControllers() {
    // Aktualizuj kontrolery tylko wtedy, gdy widget jest nadal aktywny i "zamontowany".
    if (mounted) {
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      _lowThresholdController.text = settingsService.lowGlucoseThreshold.toStringAsFixed(
        settingsService.currentGlucoseUnit == GlucoseUnit.mgDl ? 0 : 1,
      );
      _highThresholdController.text = settingsService.highGlucoseThreshold.toStringAsFixed(
        settingsService.currentGlucoseUnit == GlucoseUnit.mgDl ? 0 : 1,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
        centerTitle: true,
      ),
      // Używamy Consumer do nasłuchiwania zmian w SettingsService
      body: Consumer<SettingsService>(
        builder: (context, settingsService, child) {
          final currentUnit = settingsService.currentGlucoseUnit;
          final unitText = currentUnit == GlucoseUnit.mgDl ? 'mg/dL' : 'mmol/L';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Sekcja ustawień jednostek ---
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jednostki glikemii:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      RadioListTile<GlucoseUnit>(
                        title: const Text('mg/dL'),
                        value: GlucoseUnit.mgDl,
                        groupValue: currentUnit, // Aktualnie wybrana jednostka
                        onChanged: (GlucoseUnit? value) {
                          if (value != null) {
                            settingsService.setGlucoseUnit(value); // Ustaw nową jednostkę
                          }
                        },
                      ),
                      RadioListTile<GlucoseUnit>(
                        title: const Text('mmol/L'),
                        value: GlucoseUnit.mmolL,
                        groupValue: currentUnit,
                        onChanged: (GlucoseUnit? value) {
                          if (value != null) {
                            settingsService.setGlucoseUnit(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // --- Sekcja ustawień progów alertów ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Progi alertów:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _lowThresholdController,
                        keyboardType: TextInputType.number, // Klawiatura numeryczna
                        decoration: InputDecoration(
                          labelText: 'Próg niskiej glikemii ($unitText)',
                          border: const OutlineInputBorder(),
                          suffixText: unitText, // Wyświetlanie jednostki jako sufiks
                        ),
                        onSubmitted: (value) {
                          // Po zatwierdzeniu (np. naciśnięciu "Enter"), spróbuj sparsować wartość
                          double? newThreshold = double.tryParse(value);
                          if (newThreshold != null) {
                            // Ustaw nowy próg, przekazując wartość i aktualną jednostkę
                            settingsService.setLowGlucoseThreshold(newThreshold, currentUnit);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _highThresholdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Próg wysokiej glikemii ($unitText)',
                          border: const OutlineInputBorder(),
                          suffixText: unitText,
                        ),
                        onSubmitted: (value) {
                          double? newThreshold = double.tryParse(value);
                          if (newThreshold != null) {
                            settingsService.setHighGlucoseThreshold(newThreshold, currentUnit);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Wprowadzone progi są automatycznie zapisywane po zatwierdzeniu.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}