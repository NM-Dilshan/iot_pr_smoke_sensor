import 'package:flutter/material.dart';

import '../models/alcohol_test_result.dart';
import '../models/history_filter.dart';
import 'custom_card.dart';
import 'status_badge.dart';

class HistoryRecordCard extends StatelessWidget {
  const HistoryRecordCard({
    super.key,
    required this.record,
    required this.onTap,
  });
  final AlcoholTestResult record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${record.testType.label} Test',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${historyDate(record.timestamp)}  ${historyTime(record.timestamp)}',
            ),
            const SizedBox(height: 6),
            Text(
              'Prototype Sensor Reading: ${record.sensorReading.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 6),
            const Text('View demo record', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
