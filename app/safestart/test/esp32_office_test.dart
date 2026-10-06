import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/screens/test/alcohol_test_screen.dart';
import 'package:safestart/services/app_session.dart';
import 'package:safestart/services/demo_user_profile_repository.dart';
import 'package:safestart/services/esp32_service.dart';
import 'package:safestart/services/esp32_alcohol_sensor_service.dart';
import 'package:safestart/services/firestore_codec.dart';
import 'package:safestart/services/history_analytics_service.dart';
import 'package:safestart/widgets/emergency_alert_section.dart';

import 'support/fakes.dart';

const realResponse =
    '{"vehicleReading":94,"vehicleStatus":"SAFE","vehicleTestState":"COMPLETED","vehicleTestResult":"SAFE","vehicleResultReading":107,"vehicleTestActive":false,"officeReading":762,"officeStatus":"SAFE","officeTestState":"IDLE","officeTestResult":"NOT_TESTED","officeResultReading":0,"officeTestActive":false,"gate":"CLOSED","wifi":"CONNECTED"}';
Map<String, dynamic> office({
  String state = 'COMPLETED',
  String result = 'SAFE',
  String gate = 'CLOSED',
}) => {
  ...jsonDecode(realResponse) as Map<String, dynamic>,
  'officeTestState': state,
  'officeTestResult': result,
  'officeResultReading': state == 'COMPLETED' ? 762 : 0,
  'officeTestActive': state == 'COUNTDOWN' || state == 'SAMPLING',
  'gate': gate,
};
Esp32Service api(Future<http.Response> Function(http.Request) fn) =>
    Esp32Service(
      client: MockClient(fn),
      requestTimeout: const Duration(milliseconds: 20),
    );
Esp32AlcoholSensorService sensor(Esp32Service api) =>
    Esp32AlcoholSensorService(testType: TestType.office, esp32Service: api);
Widget session(Esp32AlcoholSensorService sensor, MemoryHistory history) =>
    AppSession(
      auth: FakeAuthService(userId: 'u'),
      profiles: DemoUserProfileRepository(),
      history: history,
      changes: SessionChanges(),
      child: MaterialApp(
        home: AlcoholTestScreen(
          testType: TestType.office,
          sensorService: sensor,
        ),
      ),
    );
Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  for (final body in [
    '{"success":true,"message":"Office test started"}',
    '{"success":true}',
  ]) {
    test('Office start accepts $body and only posts Office endpoint', () async {
      var calls = 0;
      await api((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Esp32Service.baseUrl}/office/start');
        return http.Response(body, 200);
      }).startOfficeTest();
      expect(calls, 1);
    });
  }
  for (final body in [
    '{"success":false,"message":"Rejected"}',
    'broken',
    '{}',
    '[]',
  ]) {
    test('Office start rejects $body', () async {
      await expectLater(
        api((_) async => http.Response(body, 200)).startOfficeTest(),
        throwsA(isA<Esp32Exception>()),
      );
    });
  }
  for (final code in [409, 500]) {
    test('Office HTTP $code handled', () async {
      await expectLater(
        api((_) async => http.Response('{}', code)).startOfficeTest(),
        throwsA(isA<Esp32Exception>()),
      );
    });
  }
  test('Office network failure', () async {
    await expectLater(
      api((_) async => throw http.ClientException('offline')).startOfficeTest(),
      throwsA(isA<Esp32Exception>()),
    );
  });
  test('Office request timeout', () async {
    await expectLater(
      api((_) => Completer<http.Response>().future).startOfficeTest(),
      throwsA(isA<Esp32Exception>()),
    );
  });
  test(
    'exact real status: Office IDLE with live SAFE yields no result',
    () async {
      final parsed = Esp32Status.fromJson(
        jsonDecode(realResponse) as Map<String, dynamic>,
      );
      expect(parsed.officeTestState, 'IDLE');
      expect(parsed.officeTestResult, 'NOT_TESTED');
      expect(
        await sensor(api((_) async => http.Response(realResponse, 200)))
            .pollOfficeResult(),
        isNull,
      );
    },
  );
  for (final transition in [
    ('IDLE', 'NOT_TESTED'),
    ('COUNTDOWN', 'PENDING'),
    ('SAMPLING', 'PENDING'),
  ]) {
    test(
      'Office ${transition.$1} ${transition.$2} cannot complete despite live SAFE',
      () async {
        final data = office(state: transition.$1, result: transition.$2);
        expect(Esp32Status.fromJson(data).officeResultReading, 0);
        expect(
          await sensor(api((_) async => http.Response(jsonEncode(data), 200)))
              .pollOfficeResult(),
          isNull,
        );
      },
    );
  }
  for (final gate in ['OPEN', 'CLOSED']) {
    test('Gate $gate parses without changing Office SAFE completion', () async {
      final data = office(gate: gate);
      expect(Esp32Status.fromJson(data).gate, gate);
      expect(
        (await sensor(
          api((_) async => http.Response(jsonEncode(data), 200)),
        ).pollOfficeResult())!.status,
        SafetyStatus.safe,
      );
    });
  }
  for (final safety in SafetyStatus.values) {
    test(
      'Office ${safety.name} is authoritative and raw reading roundtrips without classification',
      () async {
        // The same raw value is intentionally used for every status.
        final data = office(result: safety.name.toUpperCase());
        final parsed = Esp32Status.fromJson(data);
        expect(parsed.officeTestResult, safety.name.toUpperCase());
        final result = (await sensor(
          api((_) async => http.Response(jsonEncode(data), 200)),
        ).pollOfficeResult())!;
        expect(result.sensorReading, 762.0);
        expect(result.status, safety);
        expect(result.isEsp32Office, true);
        final encoded = FirestoreCodec.resultData(result);
        expect(encoded['source'], 'esp32_office');
        final restored = FirestoreCodec.result(encoded);
        expect(restored.testType, TestType.office);
        expect(restored.sensorReading, 762.0);
        expect(restored.status, safety);
        expect(restored.isEsp32Office, true);
        expect(
          const HistoryAnalyticsService().calculate([restored]).officeCount,
          1,
        );
      },
    );
    testWidgets(
      'Office ${safety.name} countdown, polling, access result, save and no SMS',
      (tester) async {
        final history = MemoryHistory();
        final start = Completer<http.Response>();
        var completed = false;
        var gateOpen = safety == SafetyStatus.safe;
        final paths = <String>[];
        final device = sensor(
          Esp32Service(
            client: MockClient((request) async {
              paths.add(request.url.path);
              if (request.method == 'POST') return start.future;
              return http.Response(
                jsonEncode(
                  office(
                    state: completed ? 'COMPLETED' : 'SAMPLING',
                    result: completed ? safety.name.toUpperCase() : 'PENDING',
                    gate: completed && gateOpen ? 'OPEN' : 'CLOSED',
                  ),
                ),
                200,
              );
            }),
          ),
        );
        await tester.pumpWidget(session(device, history));
        expect(paths, isEmpty);
        await tap(tester, 'START TEST');
        expect(find.text('Get Ready'), findsNothing);
        expect(find.text('CONNECTING...'), findsOneWidget);
        start.complete(
          http.Response(
            '{"success":true,"message":"Office test started"}',
            200,
          ),
        );
        await tester.pump();
        expect(find.text('3'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('2'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('BLOW NOW'), findsOneWidget);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(history.attempts, isEmpty);
        expect(find.text('VIEW RESULT'), findsNothing);
        expect(find.text('ACCESS GRANTED'), findsNothing);
        completed = true;
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(history.attempts.length, 1);
        expect(
          find.text(gateOpen ? 'GATE OPEN' : 'GATE CLOSED'),
          findsOneWidget,
        );
        if (!gateOpen) expect(find.text('GATE OPEN'), findsNothing);
        // Repeated COMPLETED status while observing the actual servo state.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        gateOpen = false;
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.text('GATE CLOSED'), findsOneWidget);
        expect(history.attempts.length, 1);
        await tap(tester, 'VIEW RESULT');
        await tester.pumpAndSettle();
        expect(find.text('Office Access Result'), findsOneWidget);
        expect(find.text(safety.name.toUpperCase()), findsOneWidget);
        expect(
          find.text(
            safety == SafetyStatus.safe ? 'ACCESS GRANTED' : 'ACCESS DENIED',
          ),
          findsOneWidget,
        );
        expect(find.text('762.00'), findsOneWidget);
        expect(find.byType(EmergencyAlertSection), findsNothing);
        expect(find.text('SEND EMERGENCY ALERT'), findsNothing);
        expect(find.textContaining('Vehicle'), findsNothing);
        expect(find.textContaining('DEMO MODE'), findsNothing);
        expect(find.text('GATE CLOSED'), findsOneWidget);
        expect(history.attempts.length, 1);
        expect(history.records.values.single.status, safety);
        expect(history.records.values.single.isEsp32Office, true);
        expect(paths.first, '/office/start');
        expect(
          paths.where((p) => p != '/office/start').every((p) => p == '/status'),
          true,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Office result screen tracks reported OPEN then CLOSED without resaving',
    (tester) async {
      final history = MemoryHistory();
      var gate = 'OPEN';
      var reachable = true;
      final device = sensor(
        Esp32Service(
          client: MockClient((request) async {
            if (request.method == 'POST') {
              return http.Response('{"success":true}', 200);
            }
            if (!reachable) throw http.ClientException('offline');
            return http.Response(jsonEncode(office(gate: gate)), 200);
          }),
        ),
      );
      await tester.pumpWidget(session(device, history));
      expect(find.text('GATE OPEN'), findsNothing);
      await tap(tester, 'START TEST');
      await tester.pump();
      expect(history.attempts.length, 1);
      await tap(tester, 'VIEW RESULT');
      await tester.pumpAndSettle();
      expect(find.text('GATE OPEN'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      gate = 'CLOSED';
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('GATE CLOSED'), findsOneWidget);
      expect(find.text('GATE OPEN'), findsNothing);
      reachable = false;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Gate state unavailable'), findsOneWidget);
      expect(history.attempts.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final type in TestType.values) {
    testWidgets(
      '${type.name} ten second progress and late completion auto-save once',
      (tester) async {
        final history = MemoryHistory();
        var completed = false;
        final service = Esp32Service(
          client: MockClient((request) async {
            if (request.method == 'POST') {
              return http.Response('{"success":true}', 200);
            }
            final data = office(
              state: completed ? 'COMPLETED' : 'SAMPLING',
              result: completed ? 'SAFE' : 'PENDING',
            );
            data['vehicleTestState'] = completed ? 'COMPLETED' : 'SAMPLING';
            data['vehicleTestResult'] = completed ? 'SAFE' : 'PENDING';
            data['vehicleTestActive'] = !completed;
            return http.Response(jsonEncode(data), 200);
          }),
        );
        final device = Esp32AlcoholSensorService(
          testType: type,
          esp32Service: service,
        );
        await tester.pumpWidget(
          AppSession(
            auth: FakeAuthService(userId: 'u'),
            profiles: DemoUserProfileRepository(),
            history: history,
            changes: SessionChanges(),
            child: MaterialApp(
              home: AlcoholTestScreen(testType: type, sensorService: device),
            ),
          ),
        );
        await tap(tester, 'START TEST');
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('BLOW NOW'), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('50%'), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('100%'), findsOneWidget);
        expect(history.attempts, isEmpty);
        // Completion after the previous 20-second timeout must still be accepted.
        for (var i = 0; i < 11; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        completed = true;
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(history.attempts.length, 1);
        expect(history.records.values.single.testType, type);
        await tester.pump(const Duration(seconds: 1));
        expect(history.attempts.length, 1);
        await tap(tester, 'VIEW RESULT');
        await tester.pumpAndSettle();
        expect(history.attempts.length, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final pair in [
    ('COMPLETED', 'PENDING'),
    ('SAMPLING', 'UNKNOWN'),
    ('UNKNOWN', 'PENDING'),
  ]) {
    test(
      'invalid Office state/result ${pair.$1}/${pair.$2} is diagnosed',
      () async {
        await expectLater(
          sensor(
            api(
              (_) async => http.Response(
                jsonEncode(office(state: pair.$1, result: pair.$2)),
                200,
              ),
            ),
          ).pollOfficeResult(),
          throwsA(
            isA<Esp32Exception>().having(
              (e) => e.diagnostic,
              'diagnostic',
              contains('officeTest'),
            ),
          ),
        );
      },
    );
  }
  testWidgets(
    'Office IDLE live SAFE times out without saving or granting access',
    (tester) async {
      final history = MemoryHistory();
      final device = sensor(
        Esp32Service(
          client: MockClient(
            (request) async => http.Response(
              request.method == 'POST' ? '{"success":true}' : realResponse,
              200,
            ),
          ),
        ),
      );
      await tester.pumpWidget(session(device, history));
      await tap(tester, 'START TEST');
      for (var i = 0; i < 32; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        find.textContaining('Office test did not reach COMPLETED'),
        findsOneWidget,
      );
      expect(find.text('VIEW RESULT'), findsNothing);
      expect(find.text('ACCESS GRANTED'), findsNothing);
      expect(history.attempts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Office invalid status never saves', (tester) async {
    final history = MemoryHistory();
    final device = sensor(
      api(
        (request) async => http.Response(
          request.method == 'POST' ? '{"success":true}' : 'broken',
          200,
        ),
      ),
    );
    await tester.pumpWidget(session(device, history));
    await tap(tester, 'START TEST');
    await tester.pumpAndSettle();
    expect(find.text('VIEW RESULT'), findsNothing);
    expect(history.attempts, isEmpty);
  });
}
