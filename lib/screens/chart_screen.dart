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

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> with WidgetsBindingObserver {
  late Future<List<SgvEntry>> _historicalDataFuture;
  int _selectedTimeRangeHours = 2;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Provider.of<SettingsService>(context, listen: false).addListener(_onSettingsChanged);
    _fetchChartData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    Provider.of<SettingsService>(context, listen: false).removeListener(_onSettingsChanged);
    _stopRefreshTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSettingsChanged() {
    _fetchChartData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchChartData();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(AppConfig.refreshDuration, (timer) {
      _fetchChartData();
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _fetchChartData() {
    setState(() {
      _historicalDataFuture = Provider.of<NightscoutDataService>(context, listen: false)
          .fetchHistoricalData(Duration(hours: _selectedTimeRangeHours));
    });
  }

  void _handleRefreshButtonPress() {
    _fetchChartData();
  }

  Widget _buildTimeRangeButton(String text, int hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedTimeRangeHours = hours;
            _fetchChartData(); 
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

    final double availableWidth = screenWidth - (2 * horizontalPadding);


    final double chartContentWidth;
    if (_selectedTimeRangeHours <= 2) {
      chartContentWidth = availableWidth;
    } else {
      double pixelsPerHour;
      if (_selectedTimeRangeHours <= 8) {
        pixelsPerHour = 100.0;
      } else {
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
                            child: const Text('Odśwież'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Consumer<SettingsService>(
                    builder: (context, settingsService, child) {
                      final List<SgvEntry> data = snapshot.data!;
                      data.sort((a, b) => a.date.compareTo(b.date));

                      final List<double> convertedSgvs = data.map((e) => settingsService.convertSgvToCurrentUnit(e.sgv)).toList();
                      
                      final double minY = (convertedSgvs.reduce(min) - 10).floorToDouble();
                      final double maxY = (convertedSgvs.reduce(max) + 10).ceilToDouble();

                      final double minX = data.first.date.millisecondsSinceEpoch.toDouble();
                      final double maxX = data.last.date.millisecondsSinceEpoch.toDouble();

                      List<FlSpot> spots = [];
                      for (int i = 0; i < data.length; i++) {
                        spots.add(FlSpot(
                          data[i].date.millisecondsSinceEpoch.toDouble(),
                          convertedSgvs[i],
                        ));
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartContentWidth,
                          height: 300,
                          child: Padding(
                            padding: const EdgeInsets.only(right: horizontalPadding, left: horizontalPadding / 2, top: 20, bottom: 20),
                            child: LineChart(
                              LineChartData(
                                lineTouchData: const LineTouchData(enabled: true),
                                gridData: const FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(DateFormat('HH:mm').format(dateTime), style: const TextStyle(fontSize: 10)),
                                        );
                                      },
                                      interval: max(1.0, (_selectedTimeRangeHours / 6)).ceil() * 60 * 60 * 1000,
                                      reservedSize: 30,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                                      },
                                      interval: (maxY - minY) / 5,
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
                                minY: minY,
                                maxY: maxY,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: false,
                                    color: Colors.blue,
                                    barWidth: 2,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
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
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: settingsService.lowGlucoseThreshold,
                                      color: const Color.fromARGB(255, 255, 0, 0),
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
                                      color: const Color.fromARGB(255, 255, 187, 0),
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