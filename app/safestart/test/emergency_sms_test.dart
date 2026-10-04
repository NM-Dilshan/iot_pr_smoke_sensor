import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/alcohol_test_result.dart';
import 'package:safestart/models/emergency_contact.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/models/sms_send_result.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/screens/test/test_result_screen.dart';
import 'package:safestart/screens/settings/emergency_contact_screen.dart';
import 'package:safestart/services/android_emergency_sms_service.dart';
import 'package:safestart/services/demo_user_profile_repository.dart';
import 'package:safestart/services/fake_emergency_sms_service.dart';
import 'package:safestart/widgets/emergency_alert_section.dart';
import 'package:safestart/services/vehicle_emergency_alert.dart';

Future<void> showAlert(
  WidgetTester tester,
  FakeEmergencySmsService fake,
) async {
  final repository = DemoUserProfileRepository();
  await repository.updateProfile(
    (await repository.getProfile()).copyWith(
      emergencyContact: const EmergencyContact(
        name: 'Test Contact',
        phoneNumber: '+94771234567',
        relationship: ContactRelationship.family,
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EmergencyAlertSection(
            profileRepository: repository,
            smsService: fake,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('missing contact opens editor and refreshes after save', (
    tester,
  ) async {
    final repository = DemoUserProfileRepository();
    final fake = FakeEmergencySmsService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EmergencyAlertSection(
              profileRepository: repository,
              smsService: fake,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No emergency contact configured.'), findsOneWidget);
    await tap(tester, 'SET EMERGENCY CONTACT');
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyContactScreen), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'New Contact');
    await tester.enterText(find.byType(TextFormField).at(1), '+94771234567');
    await tester.tap(find.byType(DropdownButtonFormField<ContactRelationship>));
    await tester.pumpAndSettle();
    await tap(tester, 'Family');
    await tap(tester, 'SAVE EMERGENCY CONTACT');
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyContactScreen), findsNothing);
    expect(find.text('New Contact'), findsOneWidget);
    expect(find.text('+94771234567'), findsOneWidget);
    expect(find.text('SEND EMERGENCY ALERT'), findsNothing);
    expect(fake.calls, 0);
  });
  for (final status in [
    SmsStatus.sent,
    SmsStatus.failed,
    SmsStatus.permissionDenied,
    SmsStatus.unsupported,
  ]) {
    testWidgets('$status automatic attempt stays truthful and cannot retry', (
      tester,
    ) async {
      final repository = DemoUserProfileRepository();
      await repository.updateProfile(
        (await repository.getProfile()).copyWith(
          emergencyContact: const EmergencyContact(
            name: 'Test Contact',
            phoneNumber: '+94771234567',
            relationship: ContactRelationship.family,
          ),
        ),
      );
      final fake = FakeEmergencySmsService(
        result: SmsSendResult(
          status,
          permanentlyDenied: status == SmsStatus.permissionDenied,
        ),
      );
      final alert = VehicleEmergencyAlert(profiles: repository, sms: fake);
      await alert.sendOnce();
      await alert.sendOnce();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyAlertSection(
              profileRepository: repository,
              smsService: fake,
              automaticAlert: alert,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.calls, 1);
      expect(find.text('SEND EMERGENCY ALERT'), findsNothing);
      expect(find.text('TRY AGAIN'), findsNothing);
      expect(find.text('Send emergency alert?'), findsNothing);
      expect(
        find.text('Emergency alert sent'),
        status == SmsStatus.sent ? findsOneWidget : findsNothing,
      );
      if (status == SmsStatus.permissionDenied) {
        expect(find.textContaining('Open Android Settings'), findsOneWidget);
      }
    });
  }
  test('concurrent automatic requests and new run have independent one-attempt guards', () async {
    final repository = DemoUserProfileRepository();
    await repository.updateProfile(
      (await repository.getProfile()).copyWith(
        emergencyContact: const EmergencyContact(
          name: 'Contact',
          phoneNumber: '+94771234567',
          relationship: ContactRelationship.family,
        ),
      ),
    );
    final pending = Completer<SmsSendResult>();
    final fake = FakeEmergencySmsService(response: pending.future);
    final alert = VehicleEmergencyAlert(profiles: repository, sms: fake);
    final first = alert.sendOnce();
    await alert.sendOnce();
    expect(fake.calls, 1);
    pending.complete(const SmsSendResult(SmsStatus.sent));
    await first;
    await alert.sendOnce();
    expect(fake.calls, 1);
    await VehicleEmergencyAlert(profiles: repository, sms: fake).sendOnce();
    expect(fake.calls, 2);
  });
  test('missing or invalid contact never calls SMS service', () async {
    final repository = DemoUserProfileRepository();
    final fake = FakeEmergencySmsService();
    final missing = VehicleEmergencyAlert(profiles: repository, sms: fake);
    await missing.sendOnce();
    expect(missing.result.status, SmsStatus.noEmergencyContact);
    await repository.updateProfile(
      (await repository.getProfile()).copyWith(
        emergencyContact: const EmergencyContact(
          name: 'Contact',
          phoneNumber: 'invalid',
          relationship: ContactRelationship.family,
        ),
      ),
    );
    await VehicleEmergencyAlert(profiles: repository, sms: fake).sendOnce();
    expect(fake.calls, 0);
  });
  for (final type in TestType.values) {
    for (final status in SafetyStatus.values) {
      testWidgets('only Vehicle DANGER exposes contact alert: $type $status', (
        tester,
      ) async {
        final fake = FakeEmergencySmsService();
        await tester.pumpWidget(
          MaterialApp(
            home: TestResultScreen(
              result: AlcoholTestResult(
                testType: type,
                sensorReading: 0.5,
                status: status,
                timestamp: DateTime(2026),
                isEsp32Vehicle: type == TestType.vehicle,
                isEsp32Office: type == TestType.office,
              ),
              profileRepository: DemoUserProfileRepository(),
              smsService: fake,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(EmergencyAlertSection),
          type == TestType.vehicle && status == SafetyStatus.danger
              ? findsOneWidget
              : findsNothing,
        );
        expect(fake.calls, 0);
      });
    }
  }
  test('Android adapter maps native results without using a SIM', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('safestart/emergency_sms');
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    for (final status in [
      'sent',
      'failed',
      'permissionDenied',
      'unsupported',
      'unknown',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'sendEmergencyAlert');
            return {
              'status': status,
              'permanentlyDenied': true,
              'canRetry': false,
            };
          });
      final result = await const AndroidEmergencySmsService()
          .sendEmergencyAlert(phoneNumber: '1234567', message: 'test');
      expect(result.status.name, status == 'unknown' ? 'failed' : status);
      expect(result.canRetry, false);
    }
  });
}
