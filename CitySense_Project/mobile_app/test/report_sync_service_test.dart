import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/offline_report.dart';
import 'package:mobile_app/models/report_submission_result.dart';
import 'package:mobile_app/services/citysense_api_client.dart';
import 'package:mobile_app/services/offline_report_repository.dart';
import 'package:mobile_app/services/report_sync_service.dart';

void main() {
  late Directory tempDir;
  late File imageFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('citysense_sync_test_');
    imageFile = File('${tempDir.path}/capture.jpg');
    await imageFile.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'deletes reachable backend rejections instead of keeping them queued',
    () async {
      final repository = _FakeOfflineReportRepository();
      final service = ReportSyncService(
        apiClient: _RejectingApiClient(isRetryable: false),
        repository: repository,
      );

      await expectLater(
        service.submitOrQueue(
          imageFile: imageFile,
          latitude: 46.77,
          longitude: 23.59,
        ),
        throwsA(isA<CitySenseApiException>()),
      );

      expect(repository.pendingCountValue, 0);
      expect(repository.failedCountValue, 0);
      expect(repository.deletedReportIds, ['client-1']);
      expect(repository.permanentFailures, isEmpty);
    },
  );

  test('keeps retryable failures queued for later synchronization', () async {
    final repository = _FakeOfflineReportRepository();
    final service = ReportSyncService(
      apiClient: _RejectingApiClient(isRetryable: true),
      repository: repository,
    );

    final outcome = await service.submitOrQueue(
      imageFile: imageFile,
      latitude: 46.77,
      longitude: 23.59,
    );

    expect(outcome.queued, isTrue);
    expect(repository.pendingCountValue, 1);
    expect(repository.deletedReportIds, isEmpty);
    expect(repository.retryableFailures, ['client-1']);
  });
}

class _RejectingApiClient extends CitySenseApiClient {
  _RejectingApiClient({required this.isRetryable}) : super(dio: Dio());

  final bool isRetryable;

  @override
  Future<bool> isBackendReachable({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return true;
  }

  @override
  Future<ReportSubmissionResult> submitReport({
    required File imageFile,
    required double latitude,
    required double longitude,
    DateTime? capturedAt,
    String? clientReportId,
  }) async {
    throw CitySenseApiException(
      'No pothole was detected in the uploaded image.',
      statusCode: isRetryable ? 503 : 422,
      isRetryable: isRetryable,
    );
  }
}

class _FakeOfflineReportRepository extends OfflineReportRepository {
  int pendingCountValue = 0;
  int failedCountValue = 0;
  final deletedReportIds = <String>[];
  final retryableFailures = <String>[];
  final permanentFailures = <String>[];
  final _reports = <String, OfflineReport>{};

  @override
  Future<OfflineReport> enqueueReport({
    required File imageFile,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
  }) async {
    final report = OfflineReport(
      clientReportId: 'client-1',
      imagePath: imageFile.path,
      latitude: latitude,
      longitude: longitude,
      capturedAt: capturedAt,
      queuedAt: DateTime.now().toUtc(),
      retryCount: 0,
      state: 'pending',
    );
    _reports[report.clientReportId] = report;
    pendingCountValue = _reports.length;
    return report;
  }

  @override
  Future<int> pendingCount() async => pendingCountValue;

  @override
  Future<int> failedCount() async => failedCountValue;

  @override
  Future<List<OfflineReport>> pendingReports() async {
    return _reports.values.toList();
  }

  @override
  Future<void> deleteReport(String clientReportId) async {
    deletedReportIds.add(clientReportId);
    _reports.remove(clientReportId);
    pendingCountValue = _reports.length;
  }

  @override
  Future<void> deleteFailedReports() async {
    failedCountValue = 0;
  }

  @override
  Future<void> markRetryableFailure({
    required String clientReportId,
    required String error,
  }) async {
    retryableFailures.add(clientReportId);
  }

  @override
  Future<void> markPermanentFailure({
    required String clientReportId,
    required String error,
  }) async {
    permanentFailures.add(clientReportId);
    failedCountValue += 1;
  }

  @override
  Future<void> close() async {}
}
