import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safestart/models/emergency_contact.dart';
import 'package:safestart/models/sms_send_result.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/screens/test/alcohol_test_screen.dart';
import 'package:safestart/screens/test/test_result_screen.dart';
import 'package:safestart/services/app_session.dart';
import 'package:safestart/services/demo_user_profile_repository.dart';
import 'package:safestart/services/esp32_alcohol_sensor_service.dart';
import 'package:safestart/services/esp32_service.dart';
import 'package:safestart/services/fake_emergency_sms_service.dart';

import 'support/fakes.dart';

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  for (final type in TestType.values) {
    for (final result in ['SAFE', 'CAUTION', 'DANGER']) {
      testWidgets(
        '$type completed $result automatic alert gating, duplicate guard and new run',
        (tester) async {
          final repository = DemoUserProfileRepository();
          await repository.updateProfile(
            (await repository.getProfile()).copyWith(
              emergencyContact: const EmergencyContact(
                name: 'Saved Contact',
                phoneNumber: '+94771234567',
                relationship: ContactRelationship.family,
              ),
            ),
          );
          final fake = FakeEmergencySmsService();
          final history = MemoryHistory();
          var state = 'IDLE';
          var polls = 0;
          final device = Esp32AlcoholSensorService(
            testType: type,
            esp32Service: Esp32Service(
              client: MockClient((request) async {
                if (request.method == 'POST') {
                  return http.Response('{"success":true}', 200);
                }
                polls++;
                return http.Response(
                  jsonEncode({
                    'vehicleReading': 3000,
                    'vehicleStatus': 'DANGER',
                    'vehicleTestState': type == TestType.vehicle
                        ? state
                        : 'COMPLETED',
                    'vehicleTestResult': type == TestType.vehicle
                        ? (state == 'COMPLETED'
                              ? result
                              : state == 'IDLE'
                              ? 'NOT_TESTED'
                              : 'PENDING')
                        : 'DANGER',
                    'vehicleResultReading': 2500,
                    'vehicleTestActive':
                        type == TestType.vehicle &&
                        state != 'IDLE' &&
                        state != 'COMPLETED',
                    'officeReading': 3000,
                    'officeStatus': 'DANGER',
                    'officeTestState': type == TestType.office ? state : 'IDLE',
                    'officeTestResult': type == TestType.office
                        ? (state == 'COMPLETED'
                              ? result
                              : state == 'IDLE'
                              ? 'NOT_TESTED'
                              : 'PENDING')
                        : 'NOT_TESTED',
                    'officeResultReading': 2500,
                    'officeTestActive':
                        type == TestType.office &&
                        state != 'IDLE' &&
                        state != 'COMPLETED',
                    'gate': 'CLOSED',
                    'wifi': 'CONNECTED',
                  }),
                  200,
                );
              }),
            ),
          );
          Widget app() => AppSession(
            auth: FakeAuthService(userId: 'user'),
            profiles: repository,
            history: history,
            changes: SessionChanges(),
            child: MaterialApp(
              home: AlcoholTestScreen(
                testType: type,
                sensorService: device,
                smsService: fake,
                profileRepository: repository,
              ),
            ),
          );
          await tester.pumpWidget(app());
          expect(fake.calls, 0);
          await tap(tester, 'START TEST');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(fake.calls, 0); // IDLE with live DANGER
          state = 'COUNTDOWN';
          await tester.pump(const Duration(seconds: 1));
          expect(fake.calls, 0);
          state = 'SAMPLING';
          for (var i = 0; i < 7; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          expect(fake.calls, 0);
          state = 'COMPLETED';
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          final expected = type == TestType.vehicle && result == 'DANGER'
              ? 1
              : 0;
          expect(fake.calls, expected); // Sends before VIEW RESULT.
          if (expected == 1) {
            expect(fake.lastPhoneNumber, '+94771234567');
            expect(find.text('Emergency alert sent'), findsOneWidget);
          }
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(fake.calls, expected);
          final completedPolls = polls;
          await tester.pump(const Duration(seconds: 2));
          expect(polls, completedPolls); // Completed polling is stopped.
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(fake.calls, expected);
          await tap(tester, 'VIEW RESULT');
          await tester.pumpAndSettle();
          expect(fake.calls, expected);
          expect(history.records.length, 1);
          expect(find.text('Send emergency alert?'), findsNothing);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tap(tester, 'VIEW RESULT');
          await tester.pumpAndSettle();
          expect(fake.calls, expected);
          expect(history.records.length, 1);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tap(tester, 'RETEST');
          state = 'SAMPLING';
          await tap(tester, 'START TEST');
          await tester.pump();
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          expect(fake.calls, expected);
          state = 'COMPLETED';
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          expect(fake.calls, expected * 2);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final smsStatus in [SmsStatus.failed, SmsStatus.permissionDenied]) {
    testWidgets(
      '$smsStatus never changes authoritative DANGER and never retries',
      (tester) async {
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
        final fake = FakeEmergencySmsService(result: SmsSendResult(smsStatus));
        final device = Esp32AlcoholSensorService(
          testType: TestType.vehicle,
          esp32Service: Esp32Service(
            client: MockClient(
              (request) async => http.Response(
                request.method == 'POST'
                    ? '{"success":true}'
                    : jsonEncode({
                        'vehicleReading': 100,
                        'vehicleStatus': 'SAFE',
                        'vehicleTestState': 'COMPLETED',
                        'vehicleTestResult': 'DANGER',
                        'vehicleResultReading': 100,
                        'vehicleTestActive': false,
                        'officeReading': 0,
                        'officeStatus': 'SAFE',
                        'gate': 'CLOSED',
                        'wifi': 'CONNECTED',
                      }),
                200,
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: AlcoholTestScreen(
              testType: TestType.vehicle,
              sensorService: device,
              profileRepository: repository,
              smsService: fake,
            ),
          ),
        );
        await tap(tester, 'START TEST');
        await tester.pumpAndSettle();
        expect(fake.calls, 1);
        await tap(tester, 'VIEW RESULT');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TestResultScreen>(find.byType(TestResultScreen))
              .result
              .status,
          SafetyStatus.danger,
        );
        expect(fake.calls, 1);
        expect(find.text('TRY AGAIN'), findsNothing);
      },
    );
  }
}
