// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cgmv4/services/nightscout_data_service.dart';
import 'package:cgmv4/services/settings_service.dart';
import 'package:cgmv4/screens/main_screen_wrapper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(
          create: (context) => NightscoutDataService(
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
        home: const MainScreenWrapper(), 
      ),
    );
  }
}

