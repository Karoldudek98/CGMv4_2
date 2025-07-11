// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/models/cgm_alert.dart';

/// Ekran wyświetlający listę alertów glikemii.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerty Glikemii'),
        centerTitle: true,
      ),
      body: Consumer<NightscoutDataService>(
        builder: (context, nightscoutService, child) {
          if (nightscoutService.alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, color: Colors.grey, size: 80),
                  SizedBox(height: 20),
                  Text(
                    'Brak aktywnych alertów.',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: nightscoutService.alerts.length,
            itemBuilder: (context, index) {
              final CgmAlert alert = nightscoutService.alerts[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                color: alert.alertColor.withOpacity(0.2), // Kolor karty zależny od alertu
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ikona alertu
                      Icon(
                        alert.type == "LOW" ? Icons.arrow_downward : Icons.arrow_upward,
                        color: alert.alertColor,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      // Treść alertu
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.message,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: alert.alertColor.darken(0.2), // Nieco ciemniejszy kolor tekstu
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm').format(alert.timestamp.toLocal()),
                              style: const TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      // Przycisk "Usuń"
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.grey),
                        onPressed: () {
                          // Wywołaj metodę usuwającą alert z serwisu
                          nightscoutService.removeAlert(alert);
                          // Opcjonalnie: pokaż snackbar z potwierdzeniem usunięcia
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alert usunięty')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Rozszerzenie dla Color, aby móc nieco przyciemnić kolor tekstu alertu
extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}