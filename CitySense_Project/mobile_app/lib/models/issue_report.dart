import 'report_status.dart';

class IssueReport {
  IssueReport({
    required this.id,
    required this.issueType,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.upvotes,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.imageUrl,
  });

  final String id;
  final String issueType;
  final double confidence;
  final double latitude;
  final double longitude;
  final String? imagePath;
  final String? imageUrl;
  final ReportStatus status;
  final int upvotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory IssueReport.fromJson(Map<String, dynamic> json) {
    return IssueReport(
      id: json['id'] as String,
      issueType: json['issue_type'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imagePath: json['image_path'] as String?,
      imageUrl: json['image_url'] as String?,
      status: ReportStatus.fromApiValue(json['status'] as String),
      upvotes: json['upvotes'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
