import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/issue_report.dart';
import '../models/offline_report.dart';
import '../models/report_status.dart';
import '../services/citysense_api_client.dart';
import '../services/offline_map_tile_provider.dart';
import '../services/report_sync_service.dart';
import '../widgets/report_details_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.apiClient,
    required this.syncService,
    super.key,
  });

  final CitySenseApiClient apiClient;
  final ReportSyncService syncService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _fallbackCenter = LatLng(46.770439, 23.591423);

  List<IssueReport> _serverReports = const [];
  List<OfflineReport> _queuedReports = const [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _backendMessage;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.syncService.addListener(_handleSyncServiceChanged);
    unawaited(_loadReports(showInitialLoading: true));
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncService != widget.syncService) {
      oldWidget.syncService.removeListener(_handleSyncServiceChanged);
      widget.syncService.addListener(_handleSyncServiceChanged);
      unawaited(_loadReports(showInitialLoading: true));
    }
  }

  @override
  void dispose() {
    widget.syncService.removeListener(_handleSyncServiceChanged);
    super.dispose();
  }

  void _handleSyncServiceChanged() {
    unawaited(_loadReports());
  }

  Future<void> _loadReports({bool showInitialLoading = false}) async {
    final generation = ++_loadGeneration;

    if (mounted) {
      setState(() {
        if (showInitialLoading) {
          _isLoading = true;
          _backendMessage = null;
        } else {
          _isRefreshing = true;
        }
      });
    }

    final queuedReports = await widget.syncService.queuedReports();
    var serverReports = _serverReports;
    String? backendMessage;

    try {
      serverReports = await widget.apiClient.fetchReports(
        status: ReportStatus.open,
      );
    } catch (error) {
      backendMessage = error.toString();
    }

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    setState(() {
      _queuedReports = queuedReports;
      _serverReports = serverReports;
      _backendMessage = backendMessage;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _syncNow() async {
    await widget.syncService.syncPendingReports();
    await _loadReports();
  }

  void _openServerDetails(IssueReport report) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReportDetailsSheet(report: report),
    );
  }

  void _openQueuedDetails(OfflineReport report) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QueuedReportDetailsSheet(report: report),
    );
  }

  List<LatLng> get _mapPoints {
    return [
      ..._queuedReports.map(
        (report) => LatLng(report.latitude, report.longitude),
      ),
      ..._serverReports.map(
        (report) => LatLng(report.latitude, report.longitude),
      ),
    ];
  }

  LatLng get _mapCenter {
    final points = _mapPoints;
    if (points.isEmpty) {
      return _fallbackCenter;
    }

    final latitude =
        points.map((point) => point.latitude).reduce((a, b) => a + b) /
        points.length;
    final longitude =
        points.map((point) => point.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(latitude, longitude);
  }

  double get _mapZoom {
    final points = _mapPoints;
    if (points.isEmpty) {
      return 12;
    }
    return points.length == 1 ? 16 : 13;
  }

  String get _mapKey {
    final queuedKey = _queuedReports
        .map((report) => '${report.clientReportId}:${report.retryCount}')
        .join(',');
    final serverKey = _serverReports
        .map((report) => '${report.id}:${report.updatedAt.toIso8601String()}')
        .join(',');
    return '$queuedKey|$serverKey';
  }

  @override
  Widget build(BuildContext context) {
    final hasQueuedReports = _queuedReports.isNotEmpty;
    final isSyncing = widget.syncService.isSyncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports map'),
        actions: [
          if (_isRefreshing || isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            onPressed: isSyncing || !hasQueuedReports
                ? null
                : () => unawaited(_syncNow()),
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sync saved reports',
          ),
          IconButton(
            onPressed: () => unawaited(_loadReports()),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh map',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            key: ValueKey(_mapKey),
            options: MapOptions(
              backgroundColor: const Color(0xFFEFF2ED),
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
            ),
            children: [
              const _OfflineBasemapLayer(),
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: OfflineMapTileProvider(),
                userAgentPackageName: 'com.example.mobile_app',
              ),
              MarkerLayer(markers: _buildServerMarkers()),
              MarkerLayer(markers: _buildQueuedMarkers()),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_statusBannerText != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _MapStatusBanner(
                  text: _statusBannerText!,
                  isSyncing: isSyncing,
                  hasError: _backendMessage != null,
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _MapReportTray(
                serverReports: _serverReports,
                queuedReports: _queuedReports,
                onOpenServerReport: _openServerDetails,
                onOpenQueuedReport: _openQueuedDetails,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Marker> _buildServerMarkers() {
    return _serverReports
        .map(
          (report) => Marker(
            point: LatLng(report.latitude, report.longitude),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () => _openServerDetails(report),
              child: Icon(
                Icons.location_on,
                color: report.upvotes >= 3
                    ? const Color(0xFFC1440E)
                    : const Color(0xFFD96C1A),
                size: 34 + report.upvotes.toDouble().clamp(0, 10).toDouble(),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildQueuedMarkers() {
    return _queuedReports
        .map(
          (report) => Marker(
            point: LatLng(report.latitude, report.longitude),
            width: 82,
            height: 82,
            child: GestureDetector(
              onTap: () => _openQueuedDetails(report),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: const Color(0xFF246B9B).withValues(alpha: 0.95),
                    size: 42,
                  ),
                  const Positioned(
                    top: 14,
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  String? get _statusBannerText {
    if (widget.syncService.isSyncing) {
      return 'Syncing saved reports with the backend and dashboard...';
    }

    if (_queuedReports.isNotEmpty && _backendMessage != null) {
      return _queuedReports.length == 1
          ? 'Offline mode: 1 saved report is shown from this phone and will sync automatically.'
          : 'Offline mode: ${_queuedReports.length} saved reports are shown from this phone and will sync automatically.';
    }

    if (_queuedReports.isNotEmpty) {
      return _queuedReports.length == 1
          ? '1 saved report is on this map until the backend accepts it.'
          : '${_queuedReports.length} saved reports are on this map until the backend accepts them.';
    }

    if (_backendMessage != null) {
      return 'Backend unavailable. Showing cached map data when available.';
    }

    return null;
  }
}

class _OfflineBasemapLayer extends StatelessWidget {
  const _OfflineBasemapLayer();

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    return MobileLayerTransformer(
      child: SizedBox(
        width: camera.size.x,
        height: camera.size.y,
        child: CustomPaint(
          painter: _OfflineBasemapPainter(
            pixelOrigin: camera.pixelOrigin,
            zoom: camera.zoom,
          ),
        ),
      ),
    );
  }
}

class _OfflineBasemapPainter extends CustomPainter {
  const _OfflineBasemapPainter({required this.pixelOrigin, required this.zoom});

  final math.Point<double> pixelOrigin;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEFF2ED),
    );

    _drawParks(canvas, size);
    _drawStreetGrid(canvas, size);
    _drawMajorRoads(canvas, size);
  }

  void _drawParks(Canvas canvas, Size size) {
    final parkPaint = Paint()
      ..color = const Color(0xFFDDEAD6)
      ..style = PaintingStyle.fill;

    final offsetX = _wrappedOffset(pixelOrigin.x, 320);
    final offsetY = _wrappedOffset(pixelOrigin.y, 260);

    for (var x = -320.0 + offsetX; x < size.width + 320; x += 320) {
      for (var y = -260.0 + offsetY; y < size.height + 260; y += 260) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 42, y + 34, 108, 72),
            const Radius.circular(24),
          ),
          parkPaint,
        );
      }
    }
  }

  void _drawStreetGrid(Canvas canvas, Size size) {
    final zoomScale = math.pow(2, (zoom - 14).clamp(-2, 2)).toDouble();
    final spacing = (58 * zoomScale).clamp(42, 92).toDouble();
    final minorPaint = Paint()
      ..color = const Color(0xFFCFD7D0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final blockPaint = Paint()
      ..color = const Color(0xFFF7F8F4).withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;

    final xStart = -_wrappedOffset(pixelOrigin.x, spacing) - spacing;
    final yStart = -_wrappedOffset(pixelOrigin.y, spacing) - spacing;

    for (var x = xStart; x < size.width + spacing; x += spacing) {
      canvas.drawLine(
        Offset(x, -20),
        Offset(x + 34, size.height + 20),
        minorPaint,
      );
    }

    for (var y = yStart; y < size.height + spacing; y += spacing) {
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y + 26),
        minorPaint,
      );
    }

    for (var x = xStart; x < size.width + spacing; x += spacing * 2) {
      for (var y = yStart; y < size.height + spacing; y += spacing * 2) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 12, y + 10, spacing * 0.72, spacing * 0.56),
            const Radius.circular(10),
          ),
          blockPaint,
        );
      }
    }
  }

  void _drawMajorRoads(Canvas canvas, Size size) {
    final casingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.64)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final roadPaint = Paint()
      ..color = const Color(0xFFB8C5BD)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shiftX = _wrappedOffset(pixelOrigin.x, size.width);
    final shiftY = _wrappedOffset(pixelOrigin.y, size.height);

    final horizontal = ui.Path()
      ..moveTo(-80 - shiftX * 0.18, size.height * 0.34)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.23 + shiftY * 0.05,
        size.width * 0.48,
        size.height * 0.45,
        size.width + 80,
        size.height * 0.28,
      );
    final vertical = ui.Path()
      ..moveTo(size.width * 0.42, -80)
      ..cubicTo(
        size.width * 0.32 + shiftX * 0.04,
        size.height * 0.28,
        size.width * 0.58,
        size.height * 0.62,
        size.width * 0.46,
        size.height + 80,
      );

    canvas
      ..drawPath(horizontal, casingPaint)
      ..drawPath(vertical, casingPaint)
      ..drawPath(horizontal, roadPaint)
      ..drawPath(vertical, roadPaint);
  }

  double _wrappedOffset(double value, double period) {
    final remainder = value % period;
    return remainder < 0 ? remainder + period : remainder;
  }

  @override
  bool shouldRepaint(covariant _OfflineBasemapPainter oldDelegate) {
    return oldDelegate.pixelOrigin != pixelOrigin || oldDelegate.zoom != zoom;
  }
}

class _MapStatusBanner extends StatelessWidget {
  const _MapStatusBanner({
    required this.text,
    required this.isSyncing,
    required this.hasError,
  });

  final String text;
  final bool isSyncing;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final tint = hasError ? const Color(0xFF246B9B) : const Color(0xFF3C7F5B);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            isSyncing
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tint,
                    ),
                  )
                : Icon(
                    hasError
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    color: tint,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2E2520),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapReportTray extends StatelessWidget {
  const _MapReportTray({
    required this.serverReports,
    required this.queuedReports,
    required this.onOpenServerReport,
    required this.onOpenQueuedReport,
  });

  final List<IssueReport> serverReports;
  final List<OfflineReport> queuedReports;
  final ValueChanged<IssueReport> onOpenServerReport;
  final ValueChanged<OfflineReport> onOpenQueuedReport;

  @override
  Widget build(BuildContext context) {
    final totalCount = serverReports.length + queuedReports.length;
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        totalCount == 1
                            ? '1 report on this map'
                            : '$totalCount reports on this map',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF211A17),
                        ),
                      ),
                    ),
                    Text(
                      '${serverReports.length} synced / ${queuedReports.length} local',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF776B63),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (totalCount == 0)
                  Text(
                    'No reports yet. Offline captures will appear here immediately after they are saved.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF625B57),
                      height: 1.35,
                    ),
                  )
                else ...[
                  for (final report in queuedReports)
                    _ReportTrayRow(
                      icon: Icons.cloud_upload_outlined,
                      tint: const Color(0xFF246B9B),
                      title: 'Saved offline report',
                      subtitle:
                          '${_formatCoordinates(report.latitude, report.longitude)} - captured ${_formatDateTime(report.capturedAt)}',
                      onTap: () => onOpenQueuedReport(report),
                    ),
                  for (final report in serverReports)
                    _ReportTrayRow(
                      icon: Icons.report_problem_outlined,
                      tint: report.upvotes >= 3
                          ? const Color(0xFFC1440E)
                          : const Color(0xFFD96C1A),
                      title:
                          '${_formatIssueType(report.issueType)} - ${report.upvotes} upvotes',
                      subtitle:
                          '${_formatCoordinates(report.latitude, report.longitude)} - latest ${_formatDateTime(report.lastPhotoReportedAt)}',
                      onTap: () => onOpenServerReport(report),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportTrayRow extends StatelessWidget {
  const _ReportTrayRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF211A17),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF776B63),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9A8D83),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueuedReportDetailsSheet extends StatelessWidget {
  const _QueuedReportDetailsSheet({required this.report});

  final OfflineReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8CEC4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDDEEFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Color(0xFF246B9B),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saved offline report',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF211A17),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Waiting for backend verification and dashboard sync',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF776B63),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.file(
                        File(report.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _ImageFallback(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QueuedDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Coordinates',
                    value: _formatCoordinates(
                      report.latitude,
                      report.longitude,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QueuedDetailRow(
                    icon: Icons.event_available_outlined,
                    label: 'Captured at',
                    value: _formatDateTime(report.capturedAt),
                  ),
                  const SizedBox(height: 10),
                  _QueuedDetailRow(
                    icon: Icons.schedule_outlined,
                    label: 'Saved locally',
                    value: _formatDateTime(report.queuedAt),
                  ),
                  if (report.retryCount > 0) ...[
                    const SizedBox(height: 10),
                    _QueuedDetailRow(
                      icon: Icons.sync_problem_outlined,
                      label: 'Sync attempts',
                      value: report.retryCount.toString(),
                    ),
                  ],
                  if (report.lastError != null) ...[
                    const SizedBox(height: 10),
                    _QueuedDetailRow(
                      icon: Icons.info_outline,
                      label: 'Last sync message',
                      value: report.lastError!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueuedDetailRow extends StatelessWidget {
  const _QueuedDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF8B7C72), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF8B7C72),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2E2520),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

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

String _formatCoordinates(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _formatIssueType(String raw) {
  return raw
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}
