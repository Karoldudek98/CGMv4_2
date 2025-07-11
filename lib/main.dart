// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cgmv4/config/app_config.dart'; // Dodaj ten import
import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/screens/main_screen_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.loadConfig(); // Dodaj tę linię
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NightscoutDataService(),
      child: MaterialApp(
        title: 'CGMv4',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            color: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        home: const MainScreenWrapper(),
      ),
    );
  }
}