import 'package:flutter/material.dart';

class ReportStatusCard extends StatelessWidget {
  const ReportStatusCard({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.info_outline,
    this.tint,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF625B57),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
