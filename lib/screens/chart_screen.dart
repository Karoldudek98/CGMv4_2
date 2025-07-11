// lib/screens/chart_screen.dart
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
      _historicalDataFuture = Provider.of<NightscoutDataService>(context, listen: false)
          .fetchHistoricalData(Duration(hours: _selectedTimeRangeHours));
    });
  }

  void _reloadHistoricalData() {
    _fetchChartData();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 16.0;
    const double chartHorizontalMargin = 32.0; // 2 * 16.0 (lewy i prawy padding)

    final double baseChartDisplayWidth = screenWidth - chartHorizontalMargin;
    final double pixelsPerHour = baseChartDisplayWidth / 2.0; 
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

                  data.sort((a, b) => a.date.compareTo(b.date));

                  if (data.isEmpty) {
                    return const Center(child: Text('Brak danych do wyświetlenia wykresu.'));
                  }
                  
                  final double minY = (data.map((e) => e.sgv).reduce(min) - 10).floorToDouble();
                  final double maxY = (data.map((e) => e.sgv).reduce(max) + 10).ceilToDouble();

                  final double minX = DateTime.now().subtract(Duration(hours: _selectedTimeRangeHours)).millisecondsSinceEpoch.toDouble();
                  final double maxX = DateTime.now().millisecondsSinceEpoch.toDouble();

                  List<FlSpot> spots = data.map((entry) {
                    return FlSpot(
                      entry.date.millisecondsSinceEpoch.toDouble(),
                      entry.sgv,
                    );
                  }).toList();

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
                                    
                                    if (_selectedTimeRangeHours <= 2) {
                                      intervalMinutes = 15; 
                                    } else if (_selectedTimeRangeHours <= 8) {
                                      intervalMinutes = 60; 
                                    } else if (_selectedTimeRangeHours <= 16) {
                                      intervalMinutes = 120; 
                                    } else { 
                                      intervalMinutes = 240; 
                                    }

                                    bool isFirstOrLast = (value - minX).abs() < 1000 || (value - maxX).abs() < 1000; 
                                    bool isIntervalMark = dateTime.minute % intervalMinutes == 0 && dateTime.second == 0;

                                    if (isIntervalMark || isFirstOrLast) {
                                      if (dateTime.minute == 0 && dateTime.second == 0) {
                                         format = DateFormat('HH:00').format(dateTime.toLocal());
                                      } else {
                                         format = DateFormat('HH:mm').format(dateTime.toLocal());
                                      }
                                    } else {
                                      return const SizedBox.shrink();
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
                                    if (value % 50 == 0) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  interval: 20,
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
      ), // Brakowało tego nawiasu zamykającego widget ElevatedButton
    );
  }
}