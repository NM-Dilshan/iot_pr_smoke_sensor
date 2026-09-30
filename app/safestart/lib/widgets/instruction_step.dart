import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'custom_card.dart';

class InstructionStep extends StatelessWidget {
  const InstructionStep({
    super.key,
    required this.number,
    required this.instruction,
  });

  final int number;
  final String instruction;

  @override
  Widget build(BuildContext context) => CustomCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            instruction,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    ),
  );
}
