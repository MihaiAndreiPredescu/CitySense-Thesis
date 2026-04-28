import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/citysense_api_client.dart';
import 'services/report_sync_service.dart';

class CitySenseApp extends StatefulWidget {
  const CitySenseApp({
    super.key,
    this.apiClient,
    this.syncService,
    this.startSyncAutomatically = true,
  });

  final CitySenseApiClient? apiClient;
  final ReportSyncService? syncService;
  final bool startSyncAutomatically;

  @override
  State<CitySenseApp> createState() => _CitySenseAppState();
}

class _CitySenseAppState extends State<CitySenseApp>
    with WidgetsBindingObserver {
  late final CitySenseApiClient _apiClient;
  late final ReportSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? CitySenseApiClient();
    _syncService =
        widget.syncService ?? ReportSyncService(apiClient: _apiClient);
    WidgetsBinding.instance.addObserver(this);

    if (widget.startSyncAutomatically) {
      unawaited(_syncService.start());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncService.syncPendingReports());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      home: HomeShell(apiClient: _apiClient, syncService: _syncService),
    );
  }
}
