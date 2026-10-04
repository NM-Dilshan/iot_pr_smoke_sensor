import 'package:flutter/material.dart';

import '../../models/test_type.dart';
import '../../widgets/test_option_card.dart';
import 'test_preparation_screen.dart';

class TestSelectionScreen extends StatelessWidget {
  const TestSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Safety Test')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose your test type',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Prototype safety test | ESP32 + MQ-3'),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 650
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final type in TestType.values)
                          SizedBox(
                            width: width,
                            child: TestOptionCard(
                              title: '${type.label} Test',
                              description: type == TestType.vehicle
                                  ? 'Check your alcohol level before driving.\n\nDesigned for pre-driving safety checks. Future sensor testing will provide a prototype safety status. Emergency safety actions may be added later.'
                                  : 'Perform a workplace alcohol screening.\n\nDesigned for workplace screening. Recording results for later review will be added in a future step. Does not control vehicle access.',
                              assetPath: type == TestType.vehicle
                                  ? 'assets/images/vehicle_test.png'
                                  : 'assets/images/office_test.png',
                              actionLabel:
                                  'SELECT ${type.label.toUpperCase()} TEST',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TestPreparationScreen(testType: type),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
