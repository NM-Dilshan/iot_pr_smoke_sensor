import 'package:flutter/material.dart';

import '../../models/alcohol_test_result.dart';
import '../../models/test_type.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_badge.dart';
import 'test_preparation_screen.dart';
import '../../services/user_profile_repository.dart';
import '../../services/demo_user_profile_repository.dart';
import '../../services/emergency_sms_service.dart';
import '../../services/android_emergency_sms_service.dart';
import '../../widgets/emergency_alert_section.dart';
import '../../services/app_session.dart';
import '../../services/completed_test_save.dart';
import '../../widgets/test_save_status.dart';
import '../../services/vehicle_emergency_alert.dart';

class TestResultScreen extends StatelessWidget {
  const TestResultScreen({
    super.key,
    required this.result,
    this.profileRepository,
    this.save,
    this.automaticAlert,
    this.smsService = const AndroidEmergencySmsService(),
  });
  final AlcoholTestResult result;
  final VehicleEmergencyAlert? automaticAlert;
  final UserProfileRepository? profileRepository;
  final CompletedTestSave? save;
  final EmergencySmsService smsService;

  @override
  Widget build(BuildContext context) {
    final vehicle = result.testType == TestType.vehicle;
    final (color, asset, message) = switch (result.status) {
      SafetyStatus.safe => (
        AppColors.safe,
        'assets/images/safe_icon.png',
        'No elevated alcohol sensor level was detected by this prototype test.',
      ),
      SafetyStatus.caution => (
        AppColors.caution,
        'assets/images/caution_icon.png',
        'An elevated sensor reading was detected.',
      ),
      SafetyStatus.danger => (
        AppColors.danger,
        'assets/images/danger_icon.png',
        'A high sensor reading was detected by the prototype.',
      ),
    };
    final title = result.isEsp32Office
        ? 'Office Access Result'
        : vehicle
        ? (result.status == SafetyStatus.danger
              ? 'Vehicle Safety Alert'
              : 'Vehicle Safety Status')
        : (result.status == SafetyStatus.danger
              ? 'Office Safety Alert'
              : 'Office Screening Status');
    final detail = result.isEsp32Office
        ? (result.status == SafetyStatus.safe
              ? 'SafeStart gate access was granted.'
              : 'SafeStart gate access was denied.')
        : switch ((result.testType, result.status)) {
            (TestType.vehicle, SafetyStatus.safe) =>
              'No restriction triggered by the prototype.',
            (TestType.vehicle, SafetyStatus.caution) =>
              'Proceeding is not recommended until the test is repeated.',
            (TestType.vehicle, SafetyStatus.danger) => 'Vehicle access would be restricted in the final SafeStart system.',
            (TestType.office, SafetyStatus.safe) =>
              'No alert triggered by the prototype.',
            (TestType.office, SafetyStatus.caution) =>
              'A repeat screening may be appropriate.',
            (TestType.office, SafetyStatus.danger) => 'High sensor reading detected by the prototype workplace screening.',
          };
    final localTime = result.timestamp.toLocal();
    final locale = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Test Result')),
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
                    'Prototype Safety Classification',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.isEsp32Hardware
                        ? 'ESP32 CONNECTED | ESP32 + MQ-3'
                        : 'DEMO MODE · SIMULATED READING',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gold, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  CustomCard(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 150,
                            height: 130,
                            child: Image.asset(
                              asset,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        StatusBadge(status: result.status),
                        const SizedBox(height: 20),
                        if (result.isEsp32Office) ...[
                          Text(
                            result.status == SafetyStatus.safe
                                ? 'ACCESS GRANTED'
                                : 'ACCESS DENIED',
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          result.isEsp32Office
                              ? 'MQ-3 Prototype Sensor Reading'
                              : 'Prototype Sensor Reading',
                        ),
                        Text(
                          result.sensorReading.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(color: color),
                        ),
                        const SizedBox(height: 12),
                        Text(message, textAlign: TextAlign.center),
                        if (result.status == SafetyStatus.caution) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Consider waiting and repeating the test before continuing.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: color),
                        ),
                        const SizedBox(height: 8),
                        Text(detail),
                        if (vehicle &&
                            result.status == SafetyStatus.danger) ...[
                          const Divider(height: 32),
                          EmergencyAlertSection(
                            profileRepository:
                                profileRepository ??
                                AppSession.maybeOf(context)?.profiles ??
                                DemoUserProfileRepository.session,
                            smsService: smsService,
                            automaticAlert: automaticAlert,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Test Type: ${result.testType.label}'),
                        const SizedBox(height: 8),
                        Text('Date: ${locale.formatMediumDate(localTime)}'),
                        const SizedBox(height: 8),
                        Text(
                          'Time: ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(localTime), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'This is an uncalibrated MQ-3 prototype sensor reading.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (save != null)
                    TestSaveStatus(save: save!)
                  else
                    const Text(
                      'Result not saved — cloud storage will be added later.',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'DONE',
                    onPressed: () =>
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TestPreparationScreen(testType: result.testType),
                      ),
                      (route) => route.isFirst,
                    ),
                    child: const Text('RETEST'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
