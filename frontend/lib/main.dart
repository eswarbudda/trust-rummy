import 'package:flutter/material.dart';

import 'screens/telemetry_screen.dart';

void main() {
  runApp(const TrustRummyApp());
}

class TrustRummyApp extends StatelessWidget {
  const TrustRummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = const Color(0xFF6C5CE7);

    return MaterialApp(
      title: 'Trust Rummy',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const TelemetryScreen(),
    );
  }
}
