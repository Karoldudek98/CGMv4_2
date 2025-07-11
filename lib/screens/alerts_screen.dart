// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Potrzebne do formatowania daty i czasu

import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/models/cgm_alert.dart'; // Import naszej klasy CgmAlert

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Używamy Consumera, aby AlertsScreen automatycznie reagował na zmiany w NightscoutDataService
    return Consumer<NightscoutDataService>(
      builder: (context, nightscoutService, child) {
        final alerts = nightscoutService.alerts; // Pobieramy listę alertów

        return Scaffold(
          appBar: AppBar(
            title: const Text('Alerty'),
            actions: [
              // Przycisk do akceptacji wszystkich alertów
              if (nightscoutService.hasUnreadAlerts) // Pokaż tylko, jeśli są nieprzeczytane alerty
                TextButton(
                  onPressed: () {
                    nightscoutService.markAllAlertsAsRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wszystkie alerty oznaczone jako przeczytane.')),
                    );
                  },
                  child: const Text(
                    'Akceptuj wszystkie',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: alerts.isEmpty // Jeśli lista alertów jest pusta
              ? const Center(child: Text('Brak aktywnych alertów.'))
              : ListView.builder(
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index]; // Pobierz pojedynczy alert
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      color: alert.alertColor.withOpacity(0.9), // Kolor karty zależny od typu alertu
                      elevation: 2, // Delikatny cień
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.message,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              // Formatowanie czasu alertu do lokalnej strefy czasowej
                              'Czas: ${DateFormat('HH:mm:ss dd.MM').format(alert.timestamp.toLocal())}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            // Ikona "nowy" dla nieprzeczytanych alertów
                            if (!alert.isRead)
                              const Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(Icons.new_releases, color: Colors.yellowAccent, size: 20),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}