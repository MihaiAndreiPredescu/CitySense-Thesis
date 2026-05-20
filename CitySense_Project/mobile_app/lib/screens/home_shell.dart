import 'dart:async';

import 'package:flutter/material.dart';

import '../services/citysense_api_client.dart';
import '../services/report_sync_service.dart';
import 'map_screen.dart';
import 'report_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.apiClient,
    required this.syncService,
    super.key,
  });

  final CitySenseApiClient apiClient;
  final ReportSyncService syncService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final List<OfflineReportVerification> _pendingVerificationDialogs = [];
  bool _isShowingVerificationDialog = false;

  @override
  void initState() {
    super.initState();
    widget.syncService.addListener(_handleSyncServiceChanged);
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncService != widget.syncService) {
      oldWidget.syncService.removeListener(_handleSyncServiceChanged);
      widget.syncService.addListener(_handleSyncServiceChanged);
      _handleSyncServiceChanged();
    }
  }

  @override
  void dispose() {
    widget.syncService.removeListener(_handleSyncServiceChanged);
    super.dispose();
  }

  void _handleSyncServiceChanged() {
    final verifications = widget.syncService.takeOfflineVerifications();
    if (verifications.isEmpty) {
      return;
    }

    _pendingVerificationDialogs.addAll(verifications);
    unawaited(_showOfflineVerificationDialogs());
  }

  Future<void> _showOfflineVerificationDialogs() async {
    if (_isShowingVerificationDialog) {
      return;
    }

    _isShowingVerificationDialog = true;
    try {
      while (mounted && _pendingVerificationDialogs.isNotEmpty) {
        final verification = _pendingVerificationDialogs.removeAt(0);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              verification.accepted
                  ? Icons.check_circle_outline
                  : Icons.search_off_outlined,
              color: verification.accepted
                  ? const Color(0xFF3C7F5B)
                  : const Color(0xFFD96C1A),
              size: 36,
            ),
            title: Text(verification.title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (verification.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.memory(
                          verification.imageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const _VerificationPhotoFallback(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(verification.message),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      _isShowingVerificationDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ReportScreen(syncService: widget.syncService),
      MapScreen(apiClient: widget.apiClient, syncService: widget.syncService),
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

class _VerificationPhotoFallback extends StatelessWidget {
  const _VerificationPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4EEE8),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFB2A69A),
        ),
      ),
    );
  }
}
