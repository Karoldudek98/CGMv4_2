// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/config/app_config.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CGMv4'),
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
      body: Consumer<NightscoutDataService>(
        builder: (context, nightscoutDataService, child) {
          if (nightscoutDataService.isLoading && nightscoutDataService.latestSgv == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final sgv = nightscoutDataService.latestSgv;

          if (sgv == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'Brak danych glikemii. Sprawdź konfigurację Nightscout w config/app_config.dart oraz połączenie z internetem.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => nightscoutDataService.fetchNightscoutData(),
                      child: const Text('Odśwież dane'),
                    ),
                  ],
                ),
              ),
            );
          }

          final String formattedTime = DateFormat('HH:mm').format(sgv.date.toLocal());
          Color sgvColor = Colors.grey;
          if (sgv.sgv > AppConfig.highGlucoseThreshold) {
            sgvColor = Colors.red;
          } else if (sgv.sgv < AppConfig.lowGlucoseThreshold) {
            sgvColor = Colors.orange;
          } else {
            sgvColor = Colors.green;
          }

          IconData trendIcon;
          Color trendColor = Colors.black87; 
          
          final String? direction = nightscoutDataService.latestSgv?.direction;

          switch (direction) {
            case "DoubleUp":
              trendIcon = Icons.keyboard_double_arrow_up;
              trendColor = Colors.red;
              break;
            case "SingleUp":
              trendIcon = Icons.arrow_upward;
              trendColor = Colors.orange;
              break;
            case "FortyFiveUp":
              trendIcon = Icons.north_east;
              trendColor = Colors.orangeAccent;
              break;
            case "Flat":
              trendIcon = Icons.arrow_right_alt;
              trendColor = Colors.green;
              break;
            case "FortyFiveDown":
              trendIcon = Icons.south_east;
              trendColor = Colors.lightBlue;
              break;
            case "SingleDown":
              trendIcon = Icons.arrow_downward;
              trendColor = Colors.blue;
              break;
            case "DoubleDown":
              trendIcon = Icons.keyboard_double_arrow_down;
              trendColor = Colors.purple;
              break;
            default: // "NONE", "NotComputable", "RateOutOfRange" lub null
              trendIcon = Icons.help_outline;
              trendColor = Colors.grey;
              break;
          }

          final delta = nightscoutDataService.glucoseDelta;
          // ZMIANA: Formatowanie delty do liczby całkowitej
          String deltaText = delta != null 
              ? '${delta > 0 ? '+' : ''}${delta.round()}' // Użycie .round() do zaokrąglenia
              : 'N/A';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sgv.sgv.toInt().toString(),
                  style: TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: sgvColor,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      trendIcon,
                      size: 48,
                      color: trendColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      deltaText,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Ostatni odczyt: $formattedTime',
                  style: const TextStyle(fontSize: 24, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}