import 'package:flutter/material.dart';

import '../services/citysense_api_client.dart';
import 'map_screen.dart';
import 'report_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.apiClient,
    super.key,
  });

  final CitySenseApiClient apiClient;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      ReportScreen(apiClient: widget.apiClient),
      MapScreen(apiClient: widget.apiClient),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
