import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/issue_report.dart';
import '../models/report_status.dart';
import '../models/report_submission_result.dart';

class CitySenseApiException implements Exception {
  CitySenseApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CitySenseApiClient {
  CitySenseApiClient({Dio? dio})
      : _dio = dio ??
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
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/reports',
        data: FormData.fromMap({
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.uri.pathSegments.last,
          ),
        }),
      );

      return ReportSubmissionResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw CitySenseApiException(_extractMessage(error));
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
      throw CitySenseApiException(_extractMessage(error));
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
      throw CitySenseApiException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic> && payload['detail'] is String) {
      return payload['detail'] as String;
    }

    return error.message ?? 'Unexpected network error.';
  }
}
