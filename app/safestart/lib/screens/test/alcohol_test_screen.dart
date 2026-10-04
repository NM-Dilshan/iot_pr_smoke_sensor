import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/alcohol_test_result.dart';
import '../../models/alcohol_test_state.dart';
import '../../models/test_type.dart';
import '../../services/alcohol_classification_service.dart';
import '../../services/alcohol_sensor_service.dart';
import '../../services/app_session.dart';
import '../../services/completed_test_save.dart';
import '../../services/mock_alcohol_sensor_service.dart';
import '../../services/esp32_alcohol_sensor_service.dart';
import '../../services/esp32_service.dart';
import '../../services/vehicle_emergency_alert.dart';
import '../../services/emergency_sms_service.dart';
import '../../services/android_emergency_sms_service.dart';
import '../../services/user_profile_repository.dart';
import '../../services/demo_user_profile_repository.dart';
import '../../models/safety_status.dart';
import '../../widgets/emergency_alert_section.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/primary_button.dart';
import 'test_result_screen.dart';

class AlcoholTestScreen extends StatefulWidget {
  const AlcoholTestScreen({
    super.key,
    required this.testType,
    this.sensorService = const MockAlcoholSensorService(),
    this.smsService = const AndroidEmergencySmsService(),
    this.profileRepository,
  });

  final TestType testType;
  final AlcoholSensorService sensorService;
  final EmergencySmsService smsService;
  final UserProfileRepository? profileRepository;

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

  bool _starting = false;
  bool get _hardware => widget.sensorService is Esp32AlcoholSensorService;
  bool _confirming = false;
  bool _allowLeave = false;
  bool _viewingResult = false;

  AlcoholTestResult? _completedResult;
  CompletedTestSave? _save;
  VehicleEmergencyAlert? _alert;

  bool get _active =>
      _starting ||
      _state == AlcoholTestState.countdown ||
      _state == AlcoholTestState.sampling;

  Future<void> _start() async {
    if (_state != AlcoholTestState.ready || _starting) return;
    if (_hardware) {
      final run = ++_run;
      setState(() {
        _starting = true;
        _error = null;
      });
      try {
        final sensor = widget.sensorService as Esp32AlcoholSensorService;
        if (widget.testType == TestType.vehicle) {
          await sensor.startVehicleTest();
        } else {
          await sensor.startOfficeTest();
        }
        if (!mounted || run != _run) return;
        setState(() => _starting = false);
        _beginCountdown();
        _pollVehicle(_run);
      } catch (error) {
        _fail(run, error);
      }
      return;
    }
    _beginCountdown();
  }

  void _beginCountdown() {
    final run = ++_run;

    setState(() {
      _state = AlcoholTestState.countdown;
      _countdown = 3;
      _samples = 0;
      _reading = null;
      _error = null;
      _completedResult = null;
      _save = null;
      _alert = null;
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
        setState(() {
          if (_samples < 5) _samples++;
        });

        if (_samples == 5) {
          timer.cancel();
          if (!_hardware) _collect(run);
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

      _complete(
        AlcoholTestResult(
          testType: widget.testType,
          sensorReading: reading,
          status: const AlcoholClassificationService().classify(reading),
          timestamp: DateTime.now(),
        ),
      );
    } catch (error) {
      _fail(run, error);
    }
  }

  Future<void> _pollVehicle(int run) async {
    final deadline = Timer(const Duration(seconds: 20), () {
      _fail(run, TimeoutException('Vehicle test did not complete.'));
      if (mounted && run == _run) _run++;
    });
    try {
      for (var polls = 0; polls < 60 && mounted && run == _run; polls++) {
        final sensor = widget.sensorService as Esp32AlcoholSensorService;
        final result = widget.testType == TestType.vehicle
            ? await sensor.pollVehicleResult()
            : await sensor.pollOfficeResult();
        if (!mounted || run != _run) return;
        if (result != null) {
          _complete(result, hardwareRun: true);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } catch (error) {
      _fail(run, error);
    } finally {
      deadline.cancel();
    }
  }

  void _complete(AlcoholTestResult result, {bool hardwareRun = false}) {
    if (_state == AlcoholTestState.completed) return;
    _timer?.cancel();
    setState(() {
      _reading = result.sensorReading;
      _state = AlcoholTestState.completed;
      _completedResult = result;
      final session = AppSession.maybeOf(context);
      if (hardwareRun &&
          widget.testType == TestType.vehicle &&
          result.testType == TestType.vehicle &&
          result.isEsp32Vehicle &&
          result.status == SafetyStatus.danger) {
        _alert = VehicleEmergencyAlert(
          profiles:
              widget.profileRepository ??
              session?.profiles ??
              DemoUserProfileRepository.session,
          sms: widget.smsService,
        );
      }
      if (session != null) {
        _save = CompletedTestSave(
          session.history,
          result,
          onSaved: session.changes.refresh,
        );
      }
    });
    if (_alert != null) unawaited(_alert!.sendOnce());
  }

  void _fail(int run, Object error) {
    if (!mounted || run != _run) return;
    _timer?.cancel();
    setState(() {
      _starting = false;
      _state = AlcoholTestState.ready;
      _samples = 0;
      _completedResult = null;
      _save = null;
      _error = error is Esp32Exception
          ? error.message
          : error is TimeoutException
          ? '${widget.testType.label} test did not reach COMPLETED. Check the SafeStart device and retry.'
          : 'Unable to collect the sensor reading. Check the device connection and try again.';
    });
  }

  void _reset() {
    _timer?.cancel();
    _run++;
    _completedResult = null;
    _save = null;
    _alert = null;

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
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _viewResult() async {
    final result = _completedResult;

    if (result == null || _viewingResult) return;

    _viewingResult = true;

    _save?.save();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TestResultScreen(
          result: result,
          save: _save,
          automaticAlert: _alert,
          profileRepository: widget.profileRepository,
          smsService: widget.smsService,
        ),
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
      if (!didPop) {
        _requestLeave();
      }
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

                  Text(
                    _hardware && _state == AlcoholTestState.completed
                        ? 'ESP32 CONNECTED'
                        : 'SafeStart Device',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Text(
                    widget.sensorService is Esp32AlcoholSensorService
                        ? 'Using real MQ-3 sensor data via Wi-Fi'
                        : 'Using simulated sensor data',
                    textAlign: TextAlign.center,
                  ),

                  const Text('SafeStart Device', textAlign: TextAlign.center),

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
                                  semanticsLabel:
                                      'MQ-3 sensor sampling progress',
                                  semanticsValue: '${(_samples * 20)}%',
                                ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            '${_samples * 20}%',
                            textAlign: TextAlign.center,
                          ),

                          const Text(
                            'Analyzing sensor sample...',
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
                            'MQ-3 prototype sensor reading',
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 20),

                        Text('Test Type: ${widget.testType.label}'),

                        const Text('Sensor: ESP32 + MQ-3'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_alert != null) ...[
                    EmergencyAlertSection(
                      profileRepository: _alert!.profiles,
                      smsService: widget.smsService,
                      automaticAlert: _alert,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),

                  if (_state == AlcoholTestState.ready)
                    PrimaryButton(
                      label: _starting ? 'CONNECTING...' : 'START TEST',
                      onPressed: _starting ? null : _start,
                    ),

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
