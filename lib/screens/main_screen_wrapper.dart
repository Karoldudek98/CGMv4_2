// lib/screens/main_screen_wrapper.dart
import 'package:flutter/material.dart';
import 'package:cgmv4/screens/home_screen.dart';
import 'package:cgmv4/screens/chart_screen.dart';
import 'package:cgmv4/screens/alerts_screen.dart'; // Import AlertsScreen
// Importujemy SettingsScreen (placeholder, jeśli jeszcze nie ma fizycznego pliku)
// Jeśli stworzyłeś osobny plik dla SettingsScreen, usuń placeholder z tego pliku i zaimportuj go stąd
// W przeciwnym razie, ten placeholder jest OK.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia (w budowie)'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Ekran ustawień jest jeszcze w budowie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}


class MainScreenWrapper extends StatefulWidget {
  const MainScreenWrapper({super.key});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  int _selectedIndex = 0; // Aktualnie wybrany indeks paska nawigacyjnego

  // Lista ekranów, które będą wyświetlane
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const ChartScreen(),
    const AlertsScreen(), // Teraz używamy faktycznego AlertsScreen
    const SettingsScreen(), // Nadal placeholder
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
        child: _widgetOptions.elementAt(_selectedIndex), // Wyświetla aktualnie wybrany ekran
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Start',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Wykres',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerty',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ustawienia',
          ),
        ],
        currentIndex: _selectedIndex, // Aktywny element
        selectedItemColor: Colors.blueAccent, // Kolor wybranego elementu
        unselectedItemColor: Colors.grey, // Kolor niewybranych elementów
        onTap: _onItemTapped, // Funkcja wywoływana po naciśnięciu elementu
        type: BottomNavigationBarType.fixed, // Zapobiega zmianie rozmiaru ikon przy naciśnięciu
      ),
    );
  }
}