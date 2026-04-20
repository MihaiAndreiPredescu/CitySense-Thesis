import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/report_submission_result.dart';
import '../services/citysense_api_client.dart';
import '../services/location_service.dart';
import '../widgets/report_status_card.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    required this.apiClient,
    super.key,
  });

  final CitySenseApiClient apiClient;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();

  File? _imageFile;
  ReportSubmissionResult? _lastSubmission;
  bool _isSubmitting = false;
  String _statusMessage =
      'Capture a pothole photo and CitySense will geotag it automatically.';

  Future<void> _captureAndSubmit() async {
    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Checking permissions and fetching your location...';
      _lastSubmission = null;
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
        _statusMessage = 'Uploading report and running pothole detection...';
      });

      final submission = await widget.apiClient.submitReport(
        imageFile: file,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _isSubmitting = false;
        _lastSubmission = submission;
        _statusMessage = submission.message;
      });
    } catch (error) {
      setState(() {
        _isSubmitting = false;
        _statusMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _lastSubmission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CitySense'),
      ),
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
                title: result == null ? 'Ready to submit' : 'Latest submission',
                message: _statusMessage,
                icon: result == null
                    ? Icons.route_outlined
                    : result.deduped
                        ? Icons.merge_type
                        : Icons.check_circle_outline,
                tint: result == null
                    ? theme.colorScheme.primary
                    : result.deduped
                        ? const Color(0xFFB45C1A)
                        : const Color(0xFF3C7F5B),
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                ReportStatusCard(
                  title: 'Report metadata',
                  message:
                      'Issue type: ${result.report.issueType}\nConfidence: ${(result.report.confidence * 100).toStringAsFixed(1)}%\nUpvotes: ${result.report.upvotes}\nStatus: ${result.report.status.label}',
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
                  label: Text(_isSubmitting ? 'Submitting...' : 'Capture & submit'),
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
