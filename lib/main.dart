// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cgmv4/screens/home_screen.dart';
import 'package:cgmv4/screens/chart_screen.dart';
import 'package:cgmv4/screens/alerts_screen.dart';
import 'package:cgmv4/screens/settings_screen.dart'; // Import nowego ekranu ustawień
import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/services/settings_service.dart'; // Import nowego serwisu ustawień

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // SettingsService musi być przed NightscoutDataService,
        // ponieważ NightscoutDataService go używa.
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(
          create: (context) => NightscoutDataService(
            // Przekazujemy instancję SettingsService do NightscoutDataService
            Provider.of<SettingsService>(context, listen: false),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'CGMv4',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Lista ekranów, które będą wyświetlane w BottomNavigationBar.
  // Teraz zawiera również SettingsScreen.
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    ChartScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.home),
                // Warunkowe wyświetlanie kropki dla powiadomień
                Consumer<NightscoutDataService>(
                  builder: (context, nightscoutService, child) {
                    if (nightscoutService.hasUnreadAlerts) {
                      return Positioned(
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: const Text(
                            '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Wykres',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerty',
          ),
          const BottomNavigationBarItem( // Nowa ikona dla Ustawień
            icon: Icon(Icons.settings),
            label: 'Ustawienia',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}