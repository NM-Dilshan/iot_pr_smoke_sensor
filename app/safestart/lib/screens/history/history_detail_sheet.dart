import 'package:flutter/material.dart';

import '../../models/alcohol_test_result.dart';
import '../../models/history_filter.dart';
import '../../widgets/status_badge.dart';

class HistoryDetailSheet extends StatelessWidget {
  const HistoryDetailSheet({super.key, required this.record});
  final AlcoholTestResult record;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.isEsp32Hardware
                ? 'MQ-3 prototype sensor record'
                : 'Prototype simulation record',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Text('Test Type: ${record.testType.label}'),
          Text('Date: ${historyDate(record.timestamp)}'),
          Text('Time: ${historyTime(record.timestamp)}'),
          const SizedBox(height: 12),
          Text(
            'Prototype Sensor Reading: ${record.sensorReading.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          const Text('Prototype Safety Classification'),
          const SizedBox(height: 8),
          StatusBadge(status: record.status),
          const SizedBox(height: 20),
          Text(
            record.isEsp32Hardware
                ? 'Real ESP32 + MQ-3 sensor data via Wi-Fi.'
                : 'Prototype simulation data; hardware is not connected.',
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    ),
  );
}
