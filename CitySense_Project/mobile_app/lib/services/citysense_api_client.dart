import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/issue_report.dart';
import '../models/report_status.dart';
import '../models/report_submission_result.dart';

class CitySenseApiException implements Exception {
  CitySenseApiException(
    this.message, {
    this.statusCode,
    this.isRetryable = false,
  });

  final String message;
  final int? statusCode;
  final bool isRetryable;

  @override
  String toString() => message;
}

class CitySenseApiClient {
  CitySenseApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  Future<ReportSubmissionResult> submitReport({
    required File imageFile,
    required double latitude,
    required double longitude,
    DateTime? capturedAt,
    String? clientReportId,
  }) async {
    try {
      final formFields = <String, dynamic>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      };
      final capturedAtValue = capturedAt?.toUtc().toIso8601String();
      if (capturedAtValue != null) {
        formFields['captured_at'] = capturedAtValue;
      }
      if (clientReportId != null) {
        formFields['client_report_id'] = clientReportId;
      }
      formFields['image'] = await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.uri.pathSegments.last,
      );

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/reports',
        data: FormData.fromMap(formFields),
      );

      return ReportSubmissionResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw CitySenseApiException(
        _extractMessage(error),
        statusCode: error.response?.statusCode,
        isRetryable: _isRetryable(error),
      );
    }
  }

  Future<bool> isBackendReachable({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      await _dio.get<Map<String, dynamic>>('/api/v1/health').timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  }

  Future<List<IssueReport>> fetchReports({ReportStatus? status}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/v1/reports',
        queryParameters: status == null ? null : {'status': status.apiValue},
      );

      return response.data!
          .map((item) => IssueReport.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw CitySenseApiException(
        _extractMessage(error),
        statusCode: error.response?.statusCode,
        isRetryable: _isRetryable(error),
      );
    }
  }

  Future<IssueReport> updateStatus({
    required String reportId,
    required ReportStatus status,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/reports/$reportId/status',
        data: {'status': status.apiValue},
      );

      return IssueReport.fromJson(response.data!);
    } on DioException catch (error) {
      throw CitySenseApiException(
        _extractMessage(error),
        statusCode: error.response?.statusCode,
        isRetryable: _isRetryable(error),
      );
    }
  }

  bool _isRetryable(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == null) {
      return true;
    }

    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  String _extractMessage(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic> && payload['detail'] is String) {
      return payload['detail'] as String;
    }

    if (_isRetryable(error)) {
      return 'Backend is not reachable. The report will be saved offline and synchronized later.';
    }

    return error.message ?? 'Unexpected network error.';
  }
}
