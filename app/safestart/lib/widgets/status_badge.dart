import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum SafetyStatus { safe, caution, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final SafetyStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SafetyStatus.safe => ('SAFE', AppColors.safe, Icons.check_circle_outline),
      SafetyStatus.caution => (
        'CAUTION',
        AppColors.caution,
        Icons.warning_amber_rounded,
      ),
      SafetyStatus.danger => ('DANGER', AppColors.danger, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
