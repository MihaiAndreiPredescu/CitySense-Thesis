import 'issue_report.dart';

class ReportSubmissionResult {
  ReportSubmissionResult({
    required this.message,
    required this.deduped,
    required this.report,
    this.clientReportId,
    this.replayed = false,
  });

  final String message;
  final bool deduped;
  final IssueReport report;
  final String? clientReportId;
  final bool replayed;

  factory ReportSubmissionResult.fromJson(Map<String, dynamic> json) {
    return ReportSubmissionResult(
      message: json['message'] as String,
      deduped: json['deduped'] as bool,
      report: IssueReport.fromJson(json['report'] as Map<String, dynamic>),
      clientReportId: json['client_report_id'] as String?,
      replayed: json['replayed'] as bool? ?? false,
    );
  }
}
