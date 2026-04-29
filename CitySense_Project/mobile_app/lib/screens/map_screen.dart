import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/issue_report.dart';
import '../models/report_status.dart';
import '../services/citysense_api_client.dart';
import '../widgets/report_details_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({required this.apiClient, super.key});

  final CitySenseApiClient apiClient;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _fallbackCenter = LatLng(46.770439, 23.591423);

  List<IssueReport> _reports = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await widget.apiClient.fetchReports(
        status: ReportStatus.open,
      );

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _openDetails(IssueReport report) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReportDetailsSheet(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _reports.isNotEmpty
        ? LatLng(_reports.first.latitude, _reports.first.longitude)
        : _fallbackCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active reports'),
        actions: [
          IconButton(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: _reports.isEmpty ? 12 : 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mobile_app',
                    ),
                    MarkerLayer(
                      markers: _reports
                          .map(
                            (report) => Marker(
                              point: LatLng(report.latitude, report.longitude),
                              width: 80,
                              height: 80,
                              child: GestureDetector(
                                onTap: () => _openDetails(report),
                                child: Icon(
                                  Icons.location_on,
                                  color: report.upvotes >= 3
                                      ? const Color(0xFFC1440E)
                                      : const Color(0xFFD96C1A),
                                  size: 34 + report.upvotes.toDouble(),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                if (_reports.isEmpty)
                  const Center(
                    child: Card(
                      margin: EdgeInsets.all(24),
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No open reports yet. Submit one from the Report tab.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
