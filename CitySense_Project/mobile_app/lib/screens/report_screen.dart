import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/report_submission_result.dart';
import '../services/citysense_api_client.dart';
import '../services/location_service.dart';
import '../services/report_sync_service.dart';
import '../widgets/report_status_card.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({required this.syncService, super.key});

  final ReportSyncService syncService;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();

  File? _imageFile;
  ReportSubmissionResult? _lastSubmission;
  bool _lastSubmissionQueued = false;
  bool _isSubmitting = false;
  String _statusMessage =
      'Capture a pothole photo and CitySense will geotag it automatically.';

  Future<void> _captureAndSubmit() async {
    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Checking permissions and fetching your location...';
      _lastSubmission = null;
      _lastSubmissionQueued = false;
    });

    try {
      final Position position = await _locationService.getCurrentPosition();

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
      );

      if (photo == null) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = 'Camera capture was cancelled.';
        });
        return;
      }

      final file = File(photo.path);
      setState(() {
        _imageFile = file;
        _statusMessage = 'Saving report and checking backend reachability...';
      });

      final outcome = await widget.syncService.submitOrQueue(
        imageFile: file,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _isSubmitting = false;
        _lastSubmission = outcome.submission;
        _lastSubmissionQueued = outcome.queued;
        _statusMessage = outcome.message;
      });
    } catch (error) {
      final rejectionMessage = _photoRejectionMessage(error);
      if (rejectionMessage != null) {
        setState(() {
          _isSubmitting = false;
          _lastSubmission = null;
          _lastSubmissionQueued = false;
          _statusMessage = rejectionMessage;
        });

        await _showNoPotholeDialog(rejectionMessage);
        if (!mounted) {
          return;
        }

        setState(() {
          _imageFile = null;
          _statusMessage =
              'No report was created. Take another photo when the pothole is clearly visible.';
        });
        return;
      }

      setState(() {
        _isSubmitting = false;
        _lastSubmissionQueued = false;
        _statusMessage = error.toString();
      });
    }
  }

  String? _photoRejectionMessage(Object error) {
    if (error is! CitySenseApiException || error.isRetryable) {
      return null;
    }

    final message = error.message.toLowerCase();
    final isDetectionRejection =
        error.statusCode == 422 &&
        (message.contains('pothole') || message.contains('detected'));
    if (!isDetectionRejection) {
      return null;
    }

    return 'CitySense did not find a pothole in this photo. The photo was not saved as a report. Please retake it with the pothole clearly visible.';
  }

  Future<void> _showNoPotholeDialog(String message) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.search_off_outlined,
          color: Color(0xFFD96C1A),
          size: 36,
        ),
        title: const Text('No pothole detected'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retake photo'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _offlineQueueMessage({
    required int pendingCount,
    required int failedCount,
    required String? lastSyncMessage,
  }) {
    final parts = <String>[];
    if (pendingCount > 0) {
      parts.add(
        pendingCount == 1
            ? '1 report is saved on this phone and waiting for the backend.'
            : '$pendingCount reports are saved on this phone and waiting for the backend.',
      );
    }

    if (failedCount > 0) {
      parts.add(
        failedCount == 1
            ? '1 saved report needs attention because the backend rejected it.'
            : '$failedCount saved reports need attention because the backend rejected them.',
      );
    }

    if (lastSyncMessage != null) {
      parts.add(lastSyncMessage);
    }

    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _lastSubmission;

    return Scaffold(
      appBar: AppBar(title: const Text('CitySense')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report a pothole in seconds',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Take a photo, let the backend detect the issue type, and merge repeat reports automatically when the location matches an existing ticket.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF625B57),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE6DDD3)),
                ),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: _imageFile == null
                        ? const Center(
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              size: 64,
                              color: Color(0xFFB2A69A),
                            ),
                          )
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ReportStatusCard(
                title: result == null
                    ? _lastSubmissionQueued
                          ? 'Saved offline'
                          : 'Ready to submit'
                    : 'Latest submission',
                message: _statusMessage,
                icon: result == null
                    ? _lastSubmissionQueued
                          ? Icons.cloud_done_outlined
                          : Icons.route_outlined
                    : result.deduped
                    ? Icons.merge_type
                    : Icons.check_circle_outline,
                tint: result == null
                    ? _lastSubmissionQueued
                          ? const Color(0xFF3C7F5B)
                          : theme.colorScheme.primary
                    : result.deduped
                    ? const Color(0xFFB45C1A)
                    : const Color(0xFF3C7F5B),
              ),
              AnimatedBuilder(
                animation: widget.syncService,
                builder: (context, _) {
                  final pendingCount = widget.syncService.pendingCount;
                  final failedCount = widget.syncService.failedCount;
                  final isSyncing = widget.syncService.isSyncing;

                  if (pendingCount == 0 && failedCount == 0 && !isSyncing) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ReportStatusCard(
                      title: isSyncing
                          ? 'Syncing offline reports'
                          : 'Offline queue',
                      message: _offlineQueueMessage(
                        pendingCount: pendingCount,
                        failedCount: failedCount,
                        lastSyncMessage: widget.syncService.lastSyncMessage,
                      ),
                      icon: isSyncing
                          ? Icons.sync
                          : pendingCount > 0
                          ? Icons.cloud_upload_outlined
                          : Icons.error_outline,
                      tint: failedCount > 0
                          ? const Color(0xFFB45C1A)
                          : theme.colorScheme.primary,
                    ),
                  );
                },
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                ReportStatusCard(
                  title: 'Report metadata',
                  message:
                      'Issue type: ${result.report.issueType}'
                      '\nConfidence: '
                      '${(result.report.confidence * 100).toStringAsFixed(1)}%'
                      '\nUpvotes: ${result.report.upvotes}'
                      '\nStatus: ${result.report.status.label}'
                      '\nCaptured at: '
                      '${_formatDateTime(result.report.capturedAt)}'
                      '\nDate and time the last photo report was taken: '
                      '${_formatDateTime(result.report.lastPhotoReportedAt)}'
                      '${result.clientReportId == null ? '' : '\nClient report ID: ${result.clientReportId}'}',
                  icon: Icons.analytics_outlined,
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _captureAndSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Capture & submit',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
