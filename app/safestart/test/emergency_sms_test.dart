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
    expect(find.text('SEND EMERGENCY ALERT'), findsOneWidget);
    expect(fake.calls, 0);
  });
  testWidgets('confirmation cancellation and pending send prevent duplicates', (
    tester,
  ) async {
    final pending = Completer<SmsSendResult>();
    final fake = FakeEmergencySmsService(response: pending.future);
    await showAlert(tester, fake);
    expect(fake.calls, 0);
    await tap(tester, 'SEND EMERGENCY ALERT');
    expect(find.textContaining('+94771234567 using'), findsOneWidget);
    expect(fake.calls, 0);
    await tap(tester, 'CANCEL');
    expect(fake.calls, 0);
    await tap(tester, 'SEND EMERGENCY ALERT');
    await tap(tester, 'SEND SMS');
    expect(fake.calls, 1);
    expect(find.text('Sending emergency alert...'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(fake.lastPhoneNumber, '+94771234567');
    expect(fake.lastMessage, EmergencyAlertSection.alertMessage);
    pending.complete(const SmsSendResult(SmsStatus.sent));
    await tester.pumpAndSettle();
    expect(find.text('Emergency alert sent'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(fake.calls, 1);
  });

  for (final status in [
    SmsStatus.failed,
    SmsStatus.permissionDenied,
    SmsStatus.unsupported,
  ]) {
    testWidgets('$status stays truthful and retries need confirmation', (
      tester,
    ) async {
      final fake = FakeEmergencySmsService(
        result: SmsSendResult(
          status,
          permanentlyDenied: status == SmsStatus.permissionDenied,
        ),
      );
      await showAlert(tester, fake);
      await tap(tester, 'SEND EMERGENCY ALERT');
      await tap(tester, 'SEND SMS');
      await tester.pumpAndSettle();
      expect(find.text('Emergency alert sent'), findsNothing);
      expect(fake.calls, 1);
      if (status == SmsStatus.permissionDenied) {
        expect(find.textContaining('Open Android Settings'), findsOneWidget);
      }
      if (status == SmsStatus.unsupported) {
        expect(find.text('TRY AGAIN'), findsNothing);
      } else {
        await tap(tester, 'TRY AGAIN');
        expect(fake.calls, 1);
        await tap(tester, 'CANCEL');
        expect(fake.calls, 1);
      }
    });
  }
  testWidgets('unknown send outcome blocks retry', (tester) async {
    final fake = FakeEmergencySmsService(
      result: const SmsSendResult(SmsStatus.failed, canRetry: false),
    );
    await showAlert(tester, fake);
    await tap(tester, 'SEND EMERGENCY ALERT');
    await tap(tester, 'SEND SMS');
    await tester.pumpAndSettle();
    expect(find.text('TRY AGAIN'), findsNothing);
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
