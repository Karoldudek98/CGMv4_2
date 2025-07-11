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
import 'package:cgmv4/services/settings_service.dart'; // Import SettingsService
import 'package:cgmv4/models/glucose_unit.dart'; // Import GlucoseUnit

/// Ekran wyświetlający wykres historycznych danych glikemii.
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> with WidgetsBindingObserver {
  late Future<List<SgvEntry>> _historicalDataFuture;
  int _selectedTimeRangeHours = 24; // Domyślny zakres czasu wykresu
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Nasłuchuj zmian w SettingsService, aby odświeżyć wykres po zmianie jednostek/progów.
    Provider.of<SettingsService>(context, listen: false).addListener(_onSettingsChanged);
    _fetchChartData(); // Pierwsze pobranie danych dla wykresu
    _startRefreshTimer(); // Uruchomienie timera odświeżania
  }

  @override
  void dispose() {
    // Usuń nasłuchiwanie SettingsService przy zwalnianiu widgetu.
    Provider.of<SettingsService>(context, listen: false).removeListener(_onSettingsChanged);
    _stopRefreshTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Metoda wywoływana, gdy SettingsService powiadomi o zmianach.
  void _onSettingsChanged() {
    _fetchChartData(); // Odśwież wykres, aby zastosować nowe jednostki/progi.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reaguj na zmiany stanu cyklu życia aplikacji.
    if (state == AppLifecycleState.resumed) {
      _fetchChartData();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopRefreshTimer();
    }
  }

  /// Rozpoczyna timer do cyklicznego odświeżania danych wykresu.
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(AppConfig.refreshDuration, (timer) {
      _fetchChartData();
    });
  }

  /// Zatrzymuje timer odświeżania danych wykresu.
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Pobiera dane historyczne z NightscoutDataService.
  void _fetchChartData() {
    setState(() {
      _historicalDataFuture = Provider.of<NightscoutDataService>(context, listen: false)
          .fetchHistoricalData(Duration(hours: _selectedTimeRangeHours));
    });
  }

  /// Obsługuje naciśnięcie przycisku odświeżania.
  void _handleRefreshButtonPress() {
    _fetchChartData();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 16.0;
    const double chartHorizontalMargin = 32.0;

    final double baseChartDisplayWidth = screenWidth - chartHorizontalMargin;
    // Współczynnik dla szerokości wykresu w zależności od zakresu czasu
    final double pixelsPerHour = baseChartDisplayWidth / (_selectedTimeRangeHours < 12 ? 4 : 2); // Większa skala dla krótszych zakresów
    final double chartContentWidth = _selectedTimeRangeHours * pixelsPerHour;

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
                  // Używamy Consumer dla SettingsService, aby wykres reagował na zmiany jednostek/progów.
                  return Consumer<SettingsService>(
                    builder: (context, settingsService, child) {
                      final List<SgvEntry> data = snapshot.data!;
                      data.sort((a, b) => a.date.compareTo(b.date));

                      // Konwersja wszystkich punktów SGV na aktualną jednostkę.
                      // Obliczanie min/max Y dla skali wykresu po konwersji.
                      final List<double> convertedSgvs = data.map((e) => settingsService.convertSgvToCurrentUnit(e.sgv)).toList();
                      
                      final double minY = (convertedSgvs.reduce(min) - 10).floorToDouble();
                      final double maxY = (convertedSgvs.reduce(max) + 10).ceilToDouble();

                      // Min/max X dla osi czasu.
                      final double minX = data.first.date.millisecondsSinceEpoch.toDouble();
                      final double maxX = data.last.date.millisecondsSinceEpoch.toDouble();

                      List<FlSpot> spots = [];
                      // Tworzenie punktów wykresu z przekonwertowanymi wartościami SGV.
                      for (int i = 0; i < data.length; i++) {
                        spots.add(FlSpot(
                          data[i].date.millisecondsSinceEpoch.toDouble(),
                          convertedSgvs[i],
                        ));
                      }
                      
                      // Pobieranie progów alertów w aktualnej jednostce.
                      final double highThreshold = settingsService.highGlucoseThreshold;
                      final double lowThreshold = settingsService.lowGlucoseThreshold;
                      final String unitText = settingsService.currentGlucoseUnit == GlucoseUnit.mgDl ? 'mg/dL' : 'mmol/L';


                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartContentWidth,
                          child: Padding(
                            padding: const EdgeInsets.all(horizontalPadding),
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: const Color(0xff37434d),
                                      strokeWidth: 0.5,
                                    );
                                  },
                                  getDrawingVerticalLine: (value) {
                                    return FlLine(
                                      color: const Color(0xff37434d),
                                      strokeWidth: 0.5,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                        String format;
                                        int intervalMinutes;
                                        
                                        // Dynamiczne dostosowanie interwału etykiet czasu
                                        if (_selectedTimeRangeHours <= 2) {
                                          intervalMinutes = 15;
                                        } else if (_selectedTimeRangeHours <= 8) {
                                          intervalMinutes = 60;
                                        } else if (_selectedTimeRangeHours <= 16) {
                                          intervalMinutes = 120;
                                        } else {
                                          intervalMinutes = 240;
                                        }

                                        // Zawsze pokazuj pierwszą i ostatnią etykietę oraz etykiety na interwałach
                                        bool isFirstOrLast = (value - minX).abs() < (5 * 60 * 1000) || (value - maxX).abs() < (5 * 60 * 1000); // Tolerancja 5 minut
                                        bool isIntervalMark = (dateTime.minute % intervalMinutes == 0 && dateTime.second == 0);

                                        if (isIntervalMark || isFirstOrLast) {
                                          if (dateTime.minute == 0 && dateTime.second == 0) {
                                              format = DateFormat('HH:00').format(dateTime.toLocal());
                                          } else {
                                              format = DateFormat('HH:mm').format(dateTime.toLocal());
                                          }
                                        } else {
                                          return const SizedBox.shrink(); // Ukryj etykiety poza interwałem
                                        }

                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          space: 8.0,
                                          child: Text(
                                            format,
                                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        // Dynamiczne dostosowanie wyświetlania wartości na osi Y.
                                        // Wartości progów też są brane pod uwagę do wyświetlenia.
                                        final bool isThresholdHigh = (value - highThreshold).abs() < 2; // Mała tolerancja dla dokładności float
                                        final bool isThresholdLow = (value - lowThreshold).abs() < 2; // Mała tolerancja dla dokładności float

                                        // Wyświetlaj etykiety co 25 mg/dL lub co 1 mmol/L
                                        if (value % (unitText == 'mg/dL' ? 25 : 1) < (unitText == 'mg/dL' ? 5 : 0.5) || isThresholdHigh || isThresholdLow) { 
                                          // Dodatkowo sprawdź, czy wartość jest blisko progu
                                          if (value < 0) return const SizedBox.shrink(); // Nie pokazuj ujemnych wartości

                                          return Text(
                                            value.toStringAsFixed(unitText == 'mg/dL' ? 0 : 1), // Formatowanie w zależności od jednostki
                                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                      interval: (unitText == 'mg/dL' ? 25 : 1), // Interwał dla osi Y zależny od jednostek
                                      reservedSize: 40,
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: const Color(0xff37434d), width: 1),
                                ),
                                minX: minX,
                                maxX: maxX,
                                minY: minY < 0 ? 0 : minY,
                                maxY: maxY,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 2,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: highThreshold, // Używamy progów z SettingsService
                                      color: Colors.red,
                                      strokeWidth: 1.5,
                                      dashArray: [5, 5],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.topRight,
                                        style: const TextStyle(color: Colors.red, fontSize: 10),
                                      ),
                                    ),
                                    HorizontalLine(
                                      y: lowThreshold, // Używamy progów z SettingsService
                                      color: Colors.orange,
                                      strokeWidth: 1.5,
                                      dashArray: [5, 5],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.bottomRight,
                                        style: const TextStyle(color: Colors.orange, fontSize: 10),
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

  /// Tworzy przycisk do wyboru zakresu czasu na wykresie.
  Widget _buildTimeRangeButton(String text, int hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedTimeRangeHours = hours;
          });
          _fetchChartData(); // Odśwież dane dla nowego zakresu
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedTimeRangeHours == hours ? Colors.blue : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text),
      ),
    );
  }
}