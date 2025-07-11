import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/config/app_config.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late Future<List<SgvEntry>> _historicalDataFuture;
  int _selectedTimeRangeHours = 24; // Domyślnie 24 godziny

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  void _fetchChartData() {
    setState(() {
      // Pobieramy dane historyczne dla wybranego zakresu czasu (np. 2h, 8h, 16h, 24h)
      _historicalDataFuture = Provider.of<NightscoutDataService>(context, listen: false)
          .fetchHistoricalData(Duration(hours: _selectedTimeRangeHours));
    });
  }

  void _reloadHistoricalData() {
    _fetchChartData();
  }

  @override
  Widget build(BuildContext context) {
    // Pobieramy szerokość ekranu
    final double screenWidth = MediaQuery.of(context).size.width;
    // Definiujemy stałe marginesy poziome dla wykresu
    const double horizontalPadding = 16.0; // Padding wewnątrz SingleChildScrollView
    const double chartHorizontalMargin = 32.0; // Całkowity margines na zewnątrz wykresu (lewy + prawy padding Scaffold)

    // Obliczamy szerokość dostępną dla samego wykresu, gdy wyświetlamy 2 godziny danych
    final double baseChartDisplayWidth = screenWidth - chartHorizontalMargin;
    
    // Obliczamy stały współczynnik "pikseli na godzinę".
    // Dla 2 godzin wykres ma dokładnie wypełniać dostępną szerokość.
    final double pixelsPerHour = baseChartDisplayWidth / 2.0; 

    // Obliczamy ostateczną szerokość zawartości wykresu. 
    // Dłuższe zakresy (8h, 16h, 24h) będą proporcjonalnie szersze i przewijalne.
    final double chartContentWidth = _selectedTimeRangeHours * pixelsPerHour;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wykres Glikemii'),
        centerTitle: true,
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
                            onPressed: _reloadHistoricalData,
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
                            onPressed: _reloadHistoricalData,
                            child: const Text('Odśwież wykres'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  final List<SgvEntry> data = snapshot.data!;

                  // Sortowanie danych, choć Nightscout API powinno już zwracać posortowane
                  data.sort((a, b) => a.date.compareTo(b.date));

                  // Jeśli dane są puste, nadal obsługa błędu
                  if (data.isEmpty) {
                    return const Center(child: Text('Brak danych do wyświetlenia wykresu.'));
                  }
                  
                  // Ustalanie zakresów osi Y (glikemii) dynamicznie
                  // Zapewnij minimum 0 dla osi Y i dodaj bufor 10 jednostek
                  final double minY = (data.map((e) => e.sgv).reduce(min) - 10).floorToDouble();
                  final double maxY = (data.map((e) => e.sgv).reduce(max) + 10).ceilToDouble();

                  // Ustalanie zakresów osi X (czasu) - KLUCZOWE: od teraz minus zakres, do teraz
                  final double minX = DateTime.now().subtract(Duration(hours: _selectedTimeRangeHours)).millisecondsSinceEpoch.toDouble();
                  final double maxX = DateTime.now().millisecondsSinceEpoch.toDouble();

                  // Konwersja danych SGV na punkty FlSpot dla wykresu
                  List<FlSpot> spots = data.map((entry) {
                    return FlSpot(
                      entry.date.millisecondsSinceEpoch.toDouble(),
                      entry.sgv,
                    );
                  }).toList();

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartContentWidth, // Używamy dynamicznie obliczonej szerokości
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
                                    
                                    // Dostosowanie interwałów wyświetlania etykiet w zależności od zakresu czasu
                                    if (_selectedTimeRangeHours <= 2) {
                                      intervalMinutes = 15; // Co 15 minut dla 2h
                                    } else if (_selectedTimeRangeHours <= 8) {
                                      intervalMinutes = 60; // Co 1 godzinę dla 8h
                                    } else if (_selectedTimeRangeHours <= 16) {
                                      intervalMinutes = 120; // Co 2 godziny dla 16h
                                    } else { // 24h
                                      intervalMinutes = 240; // Co 4 godziny dla 24h
                                    }

                                    // Sprawdź, czy czas jest wielokrotnością interwału
                                    // Dodatkowo, zawsze wyświetlaj pierwszy i ostatni punkt na osi X
                                    bool isFirstOrLast = (value - minX).abs() < 1000 || (value - maxX).abs() < 1000; // Tolerancja dla float
                                    bool isIntervalMark = dateTime.minute % intervalMinutes == 0 && dateTime.second == 0;

                                    if (isIntervalMark || isFirstOrLast) {
                                      // Jeśli czas jest blisko pełnej godziny, użyj HH:00, inaczej HH:mm
                                      if (dateTime.minute == 0 && dateTime.second == 0) {
                                         format = DateFormat('HH:00').format(dateTime.toLocal());
                                      } else {
                                         format = DateFormat('HH:mm').format(dateTime.toLocal());
                                      }
                                    } else {
                                      return const SizedBox.shrink(); // Ukryj etykietę
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
                                    // Wyświetlaj etykiety co 25 jednostek
                                    // Dodatkowo, zawsze wyświetlaj etykiety dla linii progowych, jeśli są blisko
                                    final bool isThresholdHigh = (value - AppConfig.highGlucoseThreshold).abs() < 5;
                                    final bool isThresholdLow = (value - AppConfig.lowGlucoseThreshold).abs() < 5;

                                    if (value % 25 == 0 || isThresholdHigh || isThresholdLow) {
                                      // Zapewnij, że etykieta nie będzie ujemna, jeśli minY jest niższe
                                      final int displayValue = value.toInt();
                                      if (displayValue < 0) return const SizedBox.shrink(); // Ukryj ujemne etykiety
                                      
                                      return Text(
                                        displayValue.toString(),
                                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                                      );
                                    }
                                    return const SizedBox.shrink(); // Ukryj pozostałe etykiety
                                  },
                                  interval: 25, // Ustaw interwał co 25 jednostek
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
                            minY: minY < 0 ? 0 : minY, // Zapewnij, że min Y nie będzie ujemne
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
                                  y: AppConfig.highGlucoseThreshold,
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
                                  y: AppConfig.lowGlucoseThreshold,
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
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String text, int hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedTimeRangeHours = hours;
          });
          _fetchChartData();
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