import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/citysense_api_client.dart';

class CitySenseApp extends StatelessWidget {
  const CitySenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = CitySenseApiClient();

    return MaterialApp(
      title: 'CitySense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD96C1A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F1EA),
        useMaterial3: true,
      ),
      home: HomeShell(apiClient: apiClient),
    );
  }
}
