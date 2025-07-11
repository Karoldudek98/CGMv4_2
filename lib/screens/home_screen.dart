// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/models/cgm_alert.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Funkcja pomocnicza do pobierania ikony kierunku
  IconData _getDirectionIcon(int trend) {
    switch (trend) {
      case 1: // Double Up
        return Icons.keyboard_double_arrow_up;
      case 2: // Single Up
        return Icons.keyboard_arrow_up;
      case 3: // Forty Five Up
        return Icons.arrow_outward;
      case 4: // Flat
        return Icons.arrow_forward;
      case 5: // Forty Five Down
        return Icons.south_east;
      case 6: // Single Down
        return Icons.keyboard_arrow_down;
      case 7: // Double Down
        return Icons.keyboard_double_arrow_down;
      case 8: // Not Computable
      case 9: // Rate Out of Range
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CGMv4 Home'),
        centerTitle: true,
      ),
      body: Consumer<NightscoutDataService>(
        builder: (context, nightscoutService, child) {
          final latestSgv = nightscoutService.latestSgv;

          // ZMIANA TUTAJ: Wyszukujemy alert w bezpieczny sposób.
          // Iterujemy po alertach i znajdujemy pierwszy pasujący, lub ustawiamy na null.
          CgmAlert? signalAlert;
          try {
            signalAlert = nightscoutService.alerts
                .firstWhere((alert) => alert.type == AlertType.signalLoss && !alert.isRead);
          } catch (e) {
            // Jeśli element nie zostanie znaleziony, firstWhere rzuci StateError,
            // wtedy signalAlert pozostanie null. To jest zamierzone.
            signalAlert = null; // Upewniamy się, że jest null, jeśli nie znaleziono
          }


          if (nightscoutService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Teraz 'if (signalAlert != null)' jest w pełni poprawne i potrzebne.
          if (signalAlert != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      signalAlert.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => nightscoutService.fetchNightscoutData(),
                      child: const Text('Spróbuj ponownie'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (latestSgv == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info, color: Colors.grey, size: 80),
                    const SizedBox(height: 20),
                    const Text(
                      'Brak danych glikemii. Upewnij się, że Nightscout działa i ma dane.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => nightscoutService.fetchNightscoutData(),
                      child: const Text('Odśwież dane'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${latestSgv.sgv.toInt()}',
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: latestSgv.sgv > 180 || latestSgv.sgv < 70 ? Colors.red : Colors.green,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getDirectionIcon(latestSgv.trend),
                    size: 40,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '',
                    style: TextStyle(fontSize: 30, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Ostatni odczyt: ${DateFormat('HH:mm:ss dd.MM').format(latestSgv.date.toLocal())}',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: nightscoutService.fetchNightscoutData,
                icon: const Icon(Icons.refresh),
                label: const Text('Odśwież'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),
              if (nightscoutService.hasUnreadAlerts)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.orange, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Masz ${nightscoutService.alerts.where((a) => !a.isRead).length} nowe alerty!',
                        style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          // Tutaj można by przejść do ekranu alertów
                        },
                        child: const Text('Zobacz', style: TextStyle(color: Colors.blue)),
                      )
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}