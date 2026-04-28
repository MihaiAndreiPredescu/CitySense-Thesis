class OfflineReport {
  OfflineReport({
    required this.clientReportId,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.queuedAt,
    required this.retryCount,
    required this.state,
    this.lastError,
  });

  final String clientReportId;
  final String imagePath;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final DateTime queuedAt;
  final int retryCount;
  final String state;
  final String? lastError;

  factory OfflineReport.fromMap(Map<String, Object?> map) {
    return OfflineReport(
      clientReportId: map['client_report_id'] as String,
      imagePath: map['image_path'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      capturedAt: DateTime.parse(map['captured_at'] as String),
      queuedAt: DateTime.parse(map['queued_at'] as String),
      retryCount: map['retry_count'] as int,
      state: map['state'] as String,
      lastError: map['last_error'] as String?,
    );
  }
}
