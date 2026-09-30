import 'package:flutter/material.dart';

import '../../models/test_type.dart';
import 'alcohol_test_screen.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/instruction_step.dart';
import '../../widgets/primary_button.dart';

class TestPreparationScreen extends StatefulWidget {
  const TestPreparationScreen({super.key, required this.testType});

  final TestType testType;

  @override
  State<TestPreparationScreen> createState() => _TestPreparationScreenState();
}

class _TestPreparationScreenState extends State<TestPreparationScreen> {
  bool _ready = false;

  void _continue() {
    if (!_ready) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlcoholTestScreen(testType: widget.testType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.testType == TestType.vehicle;
    final instructions = vehicle
        ? const [
            'Make sure you are not eating or drinking.',
            'Wait a short period after using mouthwash or consuming anything.',
            'Keep the phone near the SafeStart device.',
            'Make sure the SafeStart sensor device is powered on.',
            'When ready, continue to the breath test.',
          ]
        : const [
            'Ensure the SafeStart device is ready.',
            'Keep the phone near the sensor device.',
            'Follow the breath test instructions carefully.',
            'Do not eat or drink during the test.',
            'Continue when ready.',
          ];
    return Scaffold(
      appBar: AppBar(title: Text('${widget.testType.label} Safety Test')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    vehicle
                        ? 'Prepare for your alcohol breath test'
                        : 'Prepare for workplace alcohol screening',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/blow_sensor.png',
                        height: 180,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Test Type'),
                        Text(
                          widget.testType.label,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppColors.gold),
                        ),
                        const SizedBox(height: 16),
                        const Text('Device Status'),
                        const SizedBox(height: 4),
                        const Text(
                          'Demo Mode / Not Connected',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preparation instructions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < instructions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InstructionStep(
                        number: i + 1,
                        instruction: instructions[i],
                      ),
                    ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.gold,
                    checkColor: AppColors.background,
                    title: const Text(
                      'I have read the instructions and I am ready.',
                    ),
                    value: _ready,
                    onChanged: (value) =>
                        setState(() => _ready = value ?? false),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'CONTINUE TO TEST',
                    onPressed: _ready ? _continue : null,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
