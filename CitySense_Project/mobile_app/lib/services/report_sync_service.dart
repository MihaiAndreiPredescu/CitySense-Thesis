import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/offline_report.dart';
import '../models/report_submission_result.dart';
import 'citysense_api_client.dart';
import 'offline_report_repository.dart';

class OfflineSubmissionOutcome {
  OfflineSubmissionOutcome.sent(ReportSubmissionResult result)
    : submission = result,
      queuedReport = null,
      queued = false,
      message = result.message;

  OfflineSubmissionOutcome.queued(this.queuedReport, this.message)
    : submission = null,
      queued = true;

  final ReportSubmissionResult? submission;
  final OfflineReport? queuedReport;
  final bool queued;
  final String message;
}

class OfflineReportVerification {
  OfflineReportVerification({
    required this.clientReportId,
    required this.accepted,
    required this.title,
    required this.message,
    this.imageBytes,
  });

  final String clientReportId;
  final bool accepted;
  final String title;
  final String message;
  final Uint8List? imageBytes;
}

class ReportSyncService extends ChangeNotifier {
  ReportSyncService({
    required this.apiClient,
    OfflineReportRepository? repository,
    Connectivity? connectivity,
  }) : repository = repository ?? OfflineReportRepository(),
       _connectivity = connectivity ?? Connectivity();

  final CitySenseApiClient apiClient;
  final OfflineReportRepository repository;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  bool _isStarted = false;
  bool _isSyncing = false;
  int _pendingCount = 0;
  int _failedCount = 0;
  String? _lastSyncMessage;
  final List<OfflineReportVerification> _offlineVerifications = [];

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  String? get lastSyncMessage => _lastSyncMessage;

  Future<List<OfflineReport>> queuedReports() {
    return repository.queuedReports();
  }

  List<OfflineReportVerification> takeOfflineVerifications() {
    final verifications = List<OfflineReportVerification>.of(
      _offlineVerifications,
    );
    _offlineVerifications.clear();
    return verifications;
  }

  Future<void> start() async {
    if (_isStarted) {
      return;
    }

    _isStarted = true;
    await repository.deleteFailedReports();
    await _refreshCounts();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (_hasNetwork(results)) {
        unawaited(syncPendingReports());
      }
    });
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_pendingCount > 0 && !_isSyncing) {
        unawaited(syncPendingReports());
      }
    });

    final currentConnectivity = await _connectivity.checkConnectivity();
    if (_hasNetwork(currentConnectivity)) {
      unawaited(syncPendingReports());
    }
  }

  Future<OfflineSubmissionOutcome> submitOrQueue({
    required File imageFile,
    required double latitude,
    required double longitude,
  }) async {
    final localReport = await repository.enqueueReport(
      imageFile: imageFile,
      latitude: latitude,
      longitude: longitude,
      capturedAt: DateTime.now().toUtc(),
    );
    await _refreshCounts();

    if (!await apiClient.isBackendReachable()) {
      _lastSyncMessage = 'Report saved offline until the backend is reachable.';
      await repository.markRetryableFailure(
        clientReportId: localReport.clientReportId,
        error: _lastSyncMessage!,
      );
      await _refreshCounts();
      return OfflineSubmissionOutcome.queued(localReport, _lastSyncMessage!);
    }

    try {
      final submission = await _submitQueuedReport(localReport);
      _lastSyncMessage = 'Latest report was sent to the backend.';
      await _refreshCounts();
      return OfflineSubmissionOutcome.sent(submission);
    } on CitySenseApiException catch (error) {
      if (error.isRetryable) {
        await repository.markRetryableFailure(
          clientReportId: localReport.clientReportId,
          error: error.message,
        );
        _lastSyncMessage =
            'Report saved offline until the backend is reachable.';
        await _refreshCounts();
        return OfflineSubmissionOutcome.queued(localReport, _lastSyncMessage!);
      }

      await repository.deleteReport(localReport.clientReportId);
      await _refreshCounts();
      rethrow;
    } catch (error) {
      await repository.markRetryableFailure(
        clientReportId: localReport.clientReportId,
        error: error.toString(),
      );
      _lastSyncMessage = 'Report saved offline until the backend is reachable.';
      await _refreshCounts();
      return OfflineSubmissionOutcome.queued(localReport, _lastSyncMessage!);
    }
  }

  Future<void> syncPendingReports() async {
    if (_isSyncing) {
      return;
    }

    final pending = await repository.pendingReports();
    if (pending.isEmpty) {
      await _refreshCounts();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final backendReachable = await apiClient.isBackendReachable();
      if (!backendReachable) {
        _lastSyncMessage = 'Backend is not reachable yet.';
        return;
      }

      var sentCount = 0;
      for (final report in pending) {
        final imageBytes = await _readReportImage(report);
        try {
          final submission = await _submitQueuedReport(report);
          _addOfflineVerification(
            clientReportId: report.clientReportId,
            accepted: true,
            title: 'Pothole confirmed',
            message: _acceptedOfflineMessage(submission),
            imageBytes: imageBytes,
          );
          sentCount += 1;
        } on CitySenseApiException catch (error) {
          if (error.isRetryable) {
            await repository.markRetryableFailure(
              clientReportId: report.clientReportId,
              error: error.message,
            );
            _lastSyncMessage =
                'Sync paused because the backend became unreachable.';
            break;
          }

          await repository.deleteReport(report.clientReportId);
          _lastSyncMessage =
              'A saved report was not accepted: ${error.message}';
          _addOfflineVerification(
            clientReportId: report.clientReportId,
            accepted: false,
            title: 'No pothole detected',
            message:
                'The offline photo was checked by the backend, but CitySense did not detect a pothole. No report was added to the map or dashboard.\n\n${error.message}',
            imageBytes: imageBytes,
          );
        } catch (error) {
          await repository.markRetryableFailure(
            clientReportId: report.clientReportId,
            error: error.toString(),
          );
          _lastSyncMessage =
              'Sync paused because the backend became unreachable.';
          break;
        }
      }

      if (sentCount > 0) {
        _lastSyncMessage = sentCount == 1
            ? '1 offline report was synchronized.'
            : '$sentCount offline reports were synchronized.';
      }
    } finally {
      _isSyncing = false;
      await _refreshCounts();
    }
  }

  Future<ReportSubmissionResult> _submitQueuedReport(
    OfflineReport report,
  ) async {
    final submission = await apiClient.submitReport(
      imageFile: File(report.imagePath),
      latitude: report.latitude,
      longitude: report.longitude,
      capturedAt: report.capturedAt,
      clientReportId: report.clientReportId,
    );
    await repository.deleteReport(report.clientReportId);
    return submission;
  }

  void _addOfflineVerification({
    required String clientReportId,
    required bool accepted,
    required String title,
    required String message,
    Uint8List? imageBytes,
  }) {
    _offlineVerifications.add(
      OfflineReportVerification(
        clientReportId: clientReportId,
        accepted: accepted,
        title: title,
        message: message,
        imageBytes: imageBytes,
      ),
    );
  }

  Future<Uint8List?> _readReportImage(OfflineReport report) async {
    try {
      final image = File(report.imagePath);
      if (!await image.exists()) {
        return null;
      }
      return image.readAsBytes();
    } on Object {
      return null;
    }
  }

  String _acceptedOfflineMessage(ReportSubmissionResult submission) {
    final confidencePercent = (submission.report.confidence * 100).clamp(
      0,
      100,
    );
    final action = submission.deduped
        ? 'It was merged with an existing pothole report and the dashboard priority was updated.'
        : 'It was added as a new pothole report on the map and dashboard.';

    return 'The offline photo was checked by the backend and CitySense detected a pothole with ${confidencePercent.toStringAsFixed(1)}% confidence. $action';
  }

  Future<void> _refreshCounts() async {
    _pendingCount = await repository.pendingCount();
    _failedCount = await repository.failedCount();
    notifyListeners();
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(repository.close());
    super.dispose();
  }
}
