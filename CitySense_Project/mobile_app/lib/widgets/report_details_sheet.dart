import 'package:flutter/material.dart';

import '../models/issue_report.dart';

class ReportDetailsSheet extends StatelessWidget {
  const ReportDetailsSheet({
    required this.report,
    super.key,
  });

  final IssueReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.issueType.toUpperCase(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence ${(report.confidence * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text('Upvotes: ${report.upvotes}'),
          const SizedBox(height: 4),
          Text('Status: ${report.status.label}'),
          const SizedBox(height: 4),
          Text(
            'Coordinates: ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
          ),
        ],
      ),
    );
  }
}
