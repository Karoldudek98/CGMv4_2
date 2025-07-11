// lib/screens/chart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';

import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/config/app_config.dart';
import 'package:cgmv4/models/sgv_entry.dart';
import 'package:cgmv4/services/settings_service.dart';
import 'package:cgmv4/models/glucose_unit.dart';

/// Ekran wyświetlający wykres historycznych danych glikemii.
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> with WidgetsBindingObserver {
  late Future<List<SgvEntry>> _historicalDataFuture;
  int _selectedTimeRangeHours = 24; // Domyślny zakres to 24 godziny
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Nasłuchuj zmian w SettingsService, aby odświeżać wykres po zmianie jednostek/progów
    Provider.of<SettingsService>(context, listen: false).addListener(_onSettingsChanged);
    _fetchChartData(); // Pierwsze pobranie danych dla wykresu
    _startRefreshTimer(); // Uruchomienie timera odświeżania
  }

  @override
  void dispose() {
    Provider.of<SettingsService>(context, listen: false).removeListener(_onSettingsChanged);
    _stopRefreshTimer(); // Zatrzymaj timer, gdy ekran jest zwalniany
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Odśwież dane wykresu, gdy zmienią się ustawienia (np. jednostki glikemii)
    _fetchChartData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Po wznowieniu aplikacji, odśwież dane i uruchom timer
      _fetchChartData();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      // Gdy aplikacja jest w tle, zatrzymaj timer
      _stopRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel(); // Anuluj poprzedni timer, jeśli istnieje
    _refreshTimer = Timer.periodic(AppConfig.refreshDuration, (timer) {
      _fetchChartData(); // Odśwież dane cyklicznie
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel(); // Anuluj timer
    _refreshTimer = null;
  }

  void _fetchChartData() {
    setState(() {
      // Ustawia future do pobierania danych historycznych na podstawie wybranego zakresu czasu
      _historicalDataFuture = Provider.of<NightscoutDataService>(context, listen: false)
          .fetchHistoricalData(Duration(hours: _selectedTimeRangeHours));
    });
  }

  void _handleRefreshButtonPress() {
    _fetchChartData(); // Ręczne odświeżenie danych
  }

  /// Buduje przycisk do wyboru zakresu czasu dla wykresu.
  Widget _buildTimeRangeButton(String text, int hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedTimeRangeHours = hours; // Zmień wybrany zakres czasu
            _fetchChartData(); // Pobierz dane dla nowego zakresu
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: _selectedTimeRangeHours == hours ? Theme.of(context).colorScheme.primary : null,
          foregroundColor: _selectedTimeRangeHours == hours ? Theme.of(context).colorScheme.onPrimary : null,
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 16.0;

    // Szerokość dostępna dla wykresu (z uwzględnieniem paddingu bocznego dla ekranu)
    final double availableWidth = screenWidth - (2 * horizontalPadding);

    // Obliczamy chartContentWidth, tak aby wykres dla 2h był idealnie szerokości ekranu,
    // a dla dłuższych zakresów używał proporcjonalnej szerokości, ale nie mniej niż szerokość ekranu.
    final double chartContentWidth;
    if (_selectedTimeRangeHours <= 2) {
      chartContentWidth = availableWidth; // Wykres 2-godzinny zawsze na całą szerokość ekranu
    } else {
      // Współczynnik pikseli na godzinę dla pozostałych zakresów
      double pixelsPerHour;
      if (_selectedTimeRangeHours <= 8) { // Dla 8h, trochę więcej (np. 100px/h)
        pixelsPerHour = 100.0;
      } else { // Dla dłuższych zakresów, standardowo (np. 50px/h)
        pixelsPerHour = 50.0;
      }
      chartContentWidth = max(_selectedTimeRangeHours * pixelsPerHour, availableWidth);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wykres Glikemii'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefreshButtonPress,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: horizontalPadding),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeRangeButton('2h', 2),
                  _buildTimeRangeButton('8h', 8),
                  _buildTimeRangeButton('16h', 16),
                  _buildTimeRangeButton('24h', 24),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SgvEntry>>(
              future: _historicalDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(horizontalPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 80),
                          const SizedBox(height: 20),
                          Text(
                            'Błąd ładowania danych wykresu: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, color: Colors.red),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _handleRefreshButtonPress,
                            child: const Text('Spróbuj ponownie'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(horizontalPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.grey, size: 80),
                          const SizedBox(height: 20),
                          const Text(
                            'Brak danych historycznych do wyświetlenia wykresu. Upewnij się, że Nightscout działa i ma dane.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _handleRefreshButtonPress,
                            child: const Text('Odśwież wykres'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Consumer<SettingsService>(
                    builder: (context, settingsService, child) {
                      final List<SgvEntry> data = snapshot.data!;
                      data.sort((a, b) => a.date.compareTo(b.date)); // Upewnij się, że dane są posortowane chronologicznie

                      final List<double> convertedSgvs = data.map((e) => settingsService.convertSgvToCurrentUnit(e.sgv)).toList();
                      
                      // Oblicz min i max wartości SGV dla osi Y, z pewnym marginesem.
                      final double minY = (convertedSgvs.reduce(min) - 10).floorToDouble();
                      final double maxY = (convertedSgvs.reduce(max) + 10).ceilToDouble();

                      // Oblicz min i max czasu dla osi X
                      final double minX = data.first.date.millisecondsSinceEpoch.toDouble();
                      final double maxX = data.last.date.millisecondsSinceEpoch.toDouble();

                      List<FlSpot> spots = [];
                      for (int i = 0; i < data.length; i++) {
                        spots.add(FlSpot(
                          data[i].date.millisecondsSinceEpoch.toDouble(), // Czas w milisekundach jako X
                          convertedSgvs[i], // Wartość SGV w aktualnej jednostce jako Y
                        ));
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartContentWidth, // Dynamiczna szerokość wykresu
                          height: 300, // Stała wysokość wykresu
                          child: Padding(
                            padding: const EdgeInsets.only(right: horizontalPadding, left: horizontalPadding / 2, top: 20, bottom: 20),
                            child: LineChart(
                              LineChartData(
                                // Dotknięcie wykresu
                                lineTouchData: const LineTouchData(enabled: true),
                                // Linie siatki
                                gridData: const FlGridData(show: true),
                                // Tytuły osi (etykiety)
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                        // Formatowanie daty dla osi X (godzina:minuta)
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(DateFormat('HH:mm').format(dateTime), style: const TextStyle(fontSize: 10)),
                                        );
                                      },
                                      // Dynamika interwału: co ile milisekund wyświetlać etykietę.
                                      // Używamy max, aby interwał był co najmniej co godzinę,
                                      // a następnie zwiększamy go dla dłuższych zakresów.
                                      interval: max(1.0, (_selectedTimeRangeHours / 6)).ceil() * 60 * 60 * 1000,
                                      reservedSize: 30,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        // Formatowanie wartości dla osi Y
                                        return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                                      },
                                      interval: (maxY - minY) / 5, // Dzielimy zakres Y na 5 interwałów
                                      reservedSize: 40,
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                // Ramka wykresu
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: const Color(0xff37434d), width: 1),
                                ),
                                // Zakresy osi
                                minX: minX,
                                maxX: maxX,
                                minY: minY,
                                maxY: maxY,
                                // Dane linii
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: false, // Proste linie między punktami
                                    color: Colors.blue, // Kolor linii glikemii
                                    barWidth: 2,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false), // Nie pokazuj kropek na linii
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withOpacity(0.3),
                                          Colors.blue.withOpacity(0),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                                // Linie progów glikemii
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    // Linia niskiej glikemii
                                    HorizontalLine(
                                      y: settingsService.lowGlucoseThreshold,
                                      color: Colors.orange,
                                      strokeWidth: 2,
                                      dashArray: [5, 5], // Przerywana linia
                                      label: HorizontalLineLabel(
                                        show: true,
                                        labelResolver: (line) =>
                                            'Niska: ${line.y.toStringAsFixed(settingsService.currentGlucoseUnit == GlucoseUnit.mgDl ? 0 : 1)}',
                                        alignment: Alignment.topRight,
                                        style: const TextStyle(color: Colors.orange, fontSize: 10),
                                      ),
                                    ),
                                    // Linia wysokiej glikemii
                                    HorizontalLine(
                                      y: settingsService.highGlucoseThreshold,
                                      color: Colors.red,
                                      strokeWidth: 2,
                                      dashArray: [5, 5],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        labelResolver: (line) =>
                                            'Wysoka: ${line.y.toStringAsFixed(settingsService.currentGlucoseUnit == GlucoseUnit.mgDl ? 0 : 1)}',
                                        alignment: Alignment.bottomRight,
                                        style: const TextStyle(color: Colors.red, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}