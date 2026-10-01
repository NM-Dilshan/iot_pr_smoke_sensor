import '../../models/alcohol_test_result.dart';
import '../../services/alcohol_classification_service.dart';
import 'test_result_screen.dart';
import '../../services/app_session.dart';
import '../../services/completed_test_save.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/alcohol_test_state.dart';
import '../../models/test_type.dart';
import '../../services/alcohol_sensor_service.dart';
import '../../services/mock_alcohol_sensor_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/primary_button.dart';

class AlcoholTestScreen extends StatefulWidget {
  const AlcoholTestScreen({
    super.key,
    required this.testType,
    this.sensorService = const MockAlcoholSensorService(),
  });

  final TestType testType;
  final AlcoholSensorService sensorService;

  @override
  State<AlcoholTestScreen> createState() => _AlcoholTestScreenState();
}

class _AlcoholTestScreenState extends State<AlcoholTestScreen> {
  AlcoholTestState _state = AlcoholTestState.ready;
  Timer? _timer;
  int _countdown = 3;
  int _samples = 0;
  int _run = 0;
  double? _reading;
  String? _error;
  bool _confirming = false;
  bool _allowLeave = false;
  AlcoholTestResult? _completedResult;
  CompletedTestSave? _save;
  bool _viewingResult = false;

  bool get _active =>
      _state == AlcoholTestState.countdown ||
      _state == AlcoholTestState.sampling;

  void _start() {
    if (_state != AlcoholTestState.ready) return;
    final run = ++_run;
    setState(() {
      _state = AlcoholTestState.countdown;
      _countdown = 3;
      _samples = 0;
      _reading = null;
      _error = null;
      _completedResult = null;
      _save = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == AlcoholTestState.countdown) {
        setState(() {
          if (_countdown > 1) {
            _countdown--;
          } else {
            _state = AlcoholTestState.sampling;
          }
        });
      } else {
        setState(() => _samples++);
        if (_samples == 5) {
          timer.cancel();
          _collect(run);
        }
      }
    });
  }

  Future<void> _collect(int run) async {
    try {
      final reading = await widget.sensorService.readAlcoholLevel();
      if (!mounted || run != _run) return;
      if (!reading.isFinite || reading < 0) {
        throw StateError('Invalid sensor value');
      }
      setState(() {
        _reading = reading;
        _state = AlcoholTestState.completed;
        _completedResult = AlcoholTestResult(
          testType: widget.testType,
          sensorReading: reading,
          status: const AlcoholClassificationService().classify(reading),
          timestamp: DateTime.now(),
        );
        final session = AppSession.maybeOf(context);
        if (session != null) {
          _save = CompletedTestSave(
            session.history,
            _completedResult!,
            onSaved: session.changes.refresh,
          );
        }
      });
    } catch (_) {
      if (!mounted || run != _run) return;
      setState(() {
        _state = AlcoholTestState.ready;
        _samples = 0;
        _error = 'Unable to collect the simulated reading. Please try again.';
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    _run++;
    _completedResult = null;
    _save = null;
    setState(() {
      _state = AlcoholTestState.ready;
      _countdown = 3;
      _samples = 0;
      _reading = null;
      _error = null;
    });
  }

  Future<void> _requestLeave() async {
    if (_confirming || _allowLeave) return;
    if (!_active) {
      Navigator.of(context).pop();
      return;
    }
    _confirming = true;
    final cancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel current test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('KEEP TESTING'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CANCEL TEST'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _confirming = false;
    if (cancel != true) return;
    _timer?.cancel();
    _run++;
    setState(() => _allowLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _viewResult() async {
    final result = _completedResult;
    if (result == null || _viewingResult) return;
    _viewingResult = true;
    _save?.save();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TestResultScreen(result: result, save: _save),
      ),
    );
    _viewingResult = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _run++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_active || _allowLeave,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestLeave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text('${widget.testType.label} Alcohol Test'),
        leading: BackButton(onPressed: _requestLeave),
      ),
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
                    'Prototype Sensor Test',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DEMO MODE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Using simulated sensor data',
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Device Not Connected',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/blow_sensor.png',
                        height: 160,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          switch (_state) {
                            AlcoholTestState.ready => 'Ready to Test',
                            AlcoholTestState.countdown => 'Get Ready',
                            AlcoholTestState.sampling => 'BLOW NOW',
                            AlcoholTestState.completed => 'Sample Collected',
                          },
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        if (_state == AlcoholTestState.ready)
                          const Text(
                            'Take a breath and prepare to blow steadily toward the sensor.',
                            textAlign: TextAlign.center,
                          ),
                        if (_state == AlcoholTestState.countdown)
                          Text(
                            '$_countdown',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(color: AppColors.gold),
                          ),
                        if (_state == AlcoholTestState.sampling) ...[
                          const Text(
                            'Blow steadily toward the sensor',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: _samples / 5),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                                  value: value,
                                  minHeight: 8,
                                  semanticsLabel: 'Simulated sampling progress',
                                  semanticsValue: '${(_samples * 20)}%',
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_samples * 20}%',
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'Analyzing sample...',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_state == AlcoholTestState.completed) ...[
                          const Text(
                            'Sensor Reading',
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _reading!.toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(color: AppColors.gold),
                          ),
                          const Text(
                            'Simulated alcohol sensor reading',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text('Test Type: ${widget.testType.label}'),
                        const Text('Sensor: Demo Simulation'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  if (_state == AlcoholTestState.ready)
                    PrimaryButton(label: 'START TEST', onPressed: _start),
                  if (_state == AlcoholTestState.completed) ...[
                    PrimaryButton(label: 'VIEW RESULT', onPressed: _viewResult),
                    TextButton(onPressed: _reset, child: const Text('RETEST')),
                  ],
                  if (_active)
                    TextButton(
                      onPressed: _requestLeave,
                      child: const Text('CANCEL TEST'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
