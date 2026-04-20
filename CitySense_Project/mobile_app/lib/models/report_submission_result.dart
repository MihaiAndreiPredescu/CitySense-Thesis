import 'issue_report.dart';

class ReportSubmissionResult {
  ReportSubmissionResult({
    required this.message,
    required this.deduped,
    required this.report,
  });

  final String message;
  final bool deduped;
  final IssueReport report;

  factory ReportSubmissionResult.fromJson(Map<String, dynamic> json) {
    return ReportSubmissionResult(
      message: json['message'] as String,
      deduped: json['deduped'] as bool,
      report: IssueReport.fromJson(json['report'] as Map<String, dynamic>),
    );
  }
}
