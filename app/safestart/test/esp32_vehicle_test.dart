import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/services/esp32_service.dart';
import 'package:safestart/services/esp32_alcohol_sensor_service.dart';
import 'package:safestart/services/firestore_codec.dart';
import 'package:safestart/screens/test/alcohol_test_screen.dart';
import 'package:safestart/services/app_session.dart';
import 'package:safestart/services/demo_user_profile_repository.dart';

import 'support/fakes.dart';

Map<String, dynamic> status({
  String state = 'COMPLETED',
  String result = 'SAFE',
  int reading = 320,
}) => {
  'vehicleReading': 150,
  'vehicleStatus': 'SAFE',
  'vehicleTestState': state,
  'vehicleTestResult': result,
  'vehicleResultReading': reading,
  'vehicleTestActive': state != 'COMPLETED',
  'officeReading': 1200,
  'officeStatus': 'SAFE',
  'gate': 'CLOSED',
  'wifi': 'CONNECTED',
};
Esp32Service api(Future<http.Response> Function(http.Request) handler) =>
    Esp32Service(
      client: MockClient(handler),
      requestTimeout: const Duration(milliseconds: 20),
    );
void main() {
  const realResponse =
      '{"vehicleReading":94,"vehicleStatus":"SAFE","vehicleTestState":"COMPLETED","vehicleTestResult":"SAFE","vehicleResultReading":107,"vehicleTestActive":false,"officeReading":762,"officeStatus":"SAFE","officeTestState":"IDLE","officeTestResult":"NOT_TESTED","officeResultReading":0,"officeTestActive":false,"gate":"CLOSED","wifi":"CONNECTED"}';
  test(
    'exact real status response parses and completes authoritatively',
    () async {
      final parsed = Esp32Status.fromJson(
        jsonDecode(realResponse) as Map<String, dynamic>,
      );
      expect(parsed.vehicleReading, 94);
      expect(parsed.vehicleResultReading, 107);
      expect(parsed.vehicleTestResult, 'SAFE');
      expect(parsed.vehicleTestActive, false);
      expect(parsed.officeReading, 762);
      expect(parsed.officeStatus, 'SAFE');
      expect(parsed.officeTestState, 'IDLE');
      expect(parsed.officeTestResult, 'NOT_TESTED');
      expect(parsed.officeResultReading, 0);
      expect(parsed.officeTestActive, false);
      expect(parsed.gate, 'CLOSED');
      expect(parsed.wifi, 'CONNECTED');
      final service = api((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/status');
        return http.Response(realResponse, 200);
      });
      final result = (await Esp32AlcoholSensorService(
        testType: TestType.vehicle,
        esp32Service: service,
      ).pollVehicleResult())!;
      expect(result.sensorReading, 107.0);
      expect(result.status, SafetyStatus.safe);
    },
  );
  for (final transition in [
    ('COUNTDOWN', 'PENDING'),
    ('SAMPLING', 'PENDING'),
    ('IDLE', 'NOT_TESTED'),
  ]) {
    test(
      'real status transition ${transition.$1} ${transition.$2} remains incomplete',
      () async {
        final data = jsonDecode(realResponse) as Map<String, dynamic>;
        data['vehicleTestState'] = transition.$1;
        data['vehicleTestResult'] = transition.$2;
        data['vehicleResultReading'] = 0;
        data['vehicleTestActive'] = transition.$1 != 'IDLE';
        final service = api((_) async => http.Response(jsonEncode(data), 200));
        expect(
          await Esp32AlcoholSensorService(
            testType: TestType.vehicle,
            esp32Service: service,
          ).pollVehicleResult(),
          isNull,
        );
      },
    );
  }

  test('integral num readings are accepted', () {
    final data = jsonDecode(realResponse) as Map<String, dynamic>;
    for (final key in [
      'vehicleReading',
      'vehicleResultReading',
      'officeReading',
      'officeResultReading',
    ]) {
      data[key] = (data[key] as num).toDouble();
    }
    expect(Esp32Status.fromJson(data).vehicleResultReading, 107);
  });
  for (final result in ['PENDING', 'NOT_TESTED']) {
    test('COMPLETED rejects $result with field diagnostic', () async {
      final data = jsonDecode(realResponse) as Map<String, dynamic>;
      data['vehicleTestResult'] = result;
      await expectLater(
        api((_) async => http.Response(jsonEncode(data), 200)).getStatus(),
        throwsA(
          isA<Esp32Exception>().having(
            (e) => e.diagnostic,
            'diagnostic',
            contains('vehicleTestResult'),
          ),
        ),
      );
    });
  }
  for (final field in [
    'vehicleReading',
    'vehicleTestActive',
    'officeTestState',
    'officeTestResult',
    'officeResultReading',
    'officeTestActive',
  ]) {
    test(
      'invalid $field retains internal diagnostic and clean UI message',
      () async {
        final data = jsonDecode(realResponse) as Map<String, dynamic>;
        data[field] = null;
        await expectLater(
          api((_) async => http.Response(jsonEncode(data), 200)).getStatus(),
          throwsA(
            isA<Esp32Exception>()
                .having((e) => e.diagnostic, 'diagnostic', contains(field))
                .having(
                  (e) => e.message,
                  'UI message',
                  'Invalid JSON or status response from the SafeStart device.',
                ),
          ),
        );
      },
    );
  }
  test('new status preserves live, final and Office fields', () {
    final value = Esp32Status.fromJson(status());
    expect(value.vehicleReading, 150);
    expect(value.vehicleResultReading, 320);
    expect(value.vehicleTestState, 'COMPLETED');
    expect(value.vehicleTestResult, 'SAFE');
    expect(value.vehicleTestActive, false);
    expect(value.officeReading, 1200);
    expect(value.officeStatus, 'SAFE');
    expect(value.gate, 'CLOSED');
    expect(value.wifi, 'CONNECTED');
  });
  test('start sends only POST vehicle/start and accepts 200', () async {
    await api((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), '${Esp32Service.baseUrl}/vehicle/start');
      return http.Response(
        '{"success":true,"message":"Vehicle test started"}',
        200,
      );
    }).startVehicleTest();
  });
  test(
    'start accepts success true without a message or status fields',
    () async {
      await api((_) async => http.Response('{"success":true}', 200))
          .startVehicleTest();
    },
  );
  for (final body in [
    '{"success":false,"message":"Test rejected"}',
    '{}',
    '{"success":"true"}',
    '{"success":1}',
    '[]',
    '',
  ]) {
    test('start rejects acknowledgement $body', () async {
      await expectLater(
        api((_) async => http.Response(body, 200)).startVehicleTest(),
        throwsA(isA<Esp32Exception>()),
      );
    });
  }
  test('GET status rejects a START acknowledgement', () async {
    await expectLater(
      api(
        (_) async => http.Response(
          '{"success":true,"message":"Vehicle test started"}',
          200,
        ),
      ).getStatus(),
      throwsA(isA<Esp32Exception>()),
    );
  });
  for (final code in [409, 500]) {
    test('start rejects HTTP $code', () async {
      await expectLater(
        api((_) async => http.Response('{}', code)).startVehicleTest(),
        throwsA(isA<Esp32Exception>()),
      );
    });
  }
  test('unreachable device has network guidance', () async {
    await expectLater(
      api((_) async => throw http.ClientException('offline')).getStatus(),
      throwsA(
        isA<Esp32Exception>().having(
          (e) => e.message,
          'message',
          contains('same Wi-Fi'),
        ),
      ),
    );
  });
  test('request timeout', () async {
    await expectLater(
      api((_) => Completer<http.Response>().future).startVehicleTest(),
      throwsA(
        isA<Esp32Exception>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });
  for (final body in [
    'broken',
    '[]',
    '{}',
    jsonEncode(status(result: 'UNKNOWN')),
  ]) {
    test('invalid status $body rejected', () async {
      await expectLater(
        api((_) async => http.Response(body, 200)).getStatus(),
        throwsA(isA<Esp32Exception>()),
      );
    });
  }
  test('invalid start response rejected', () async {
    await expectLater(
      api((_) async => http.Response('broken', 200)).startVehicleTest(),
      throwsA(isA<Esp32Exception>()),
    );
  });
  for (final safety in SafetyStatus.values) {
    test(
      '${safety.name} uses authoritative result without reclassification and roundtrips',
      () async {
        // Deliberately inconsistent with both old and raw thresholds.
        final sensor = Esp32AlcoholSensorService(
          testType: TestType.vehicle,
          esp32Service: api(
            (_) async => http.Response(
              jsonEncode(
                status(result: safety.name.toUpperCase(), reading: 320),
              ),
              200,
            ),
          ),
        );
        final result = (await sensor.pollVehicleResult())!;
        expect(result.status, safety);
        expect(result.sensorReading, 320.0);
        expect(result.isEsp32Vehicle, true);
        final restored = FirestoreCodec.result(
          FirestoreCodec.resultData(result),
        );
        expect(restored.status, safety);
        expect(restored.sensorReading, 320.0);
        expect(restored.isEsp32Vehicle, true);
      },
    );
  }
  test('incomplete sampling yields no result', () async {
    final sensor = Esp32AlcoholSensorService(
      testType: TestType.vehicle,
      esp32Service: api(
        (_) async => http.Response(jsonEncode(status(state: 'SAMPLING')), 200),
      ),
    );
    expect(await sensor.pollVehicleResult(), isNull);
    await expectLater(sensor.readAlcoholLevel(), throwsStateError);
  });
  for (final safety in SafetyStatus.values) {
    testWidgets(
      'Vehicle ${safety.name} completion displays and saves ESP32 result',
      (tester) async {
        final history = MemoryHistory();
        final start = Completer<http.Response>();
        var completed = false;
        final sensor = Esp32AlcoholSensorService(
          testType: TestType.vehicle,
          esp32Service: Esp32Service(
            client: MockClient((request) async {
              if (request.method == 'POST') return start.future;
              return http.Response(
                jsonEncode(
                  status(
                    state: completed ? 'COMPLETED' : 'SAMPLING',
                    result: safety.name.toUpperCase(),
                  ),
                ),
                200,
              );
            }),
          ),
        );
        await tester.pumpWidget(
          AppSession(
            auth: FakeAuthService(userId: 'u'),
            profiles: DemoUserProfileRepository(),
            history: history,
            changes: SessionChanges(),
            child: MaterialApp(
              home: AlcoholTestScreen(
                testType: TestType.vehicle,
                sensorService: sensor,
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text('START TEST'));
        await tester.tap(find.text('START TEST'));
        await tester.pump();
        start.complete(
          http.Response(
            '{"success":true,"message":"Vehicle test started"}',
            200,
          ),
        );
        await tester.pump();
        for (var i = 0; i < 13; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('BLOW NOW'), findsOneWidget);
        expect(history.attempts, isEmpty);
        completed = true;
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(history.attempts.length, 1);
        expect(history.records.values.single.isEsp32Vehicle, true);
        await tester.ensureVisible(find.text('VIEW RESULT'));
        await tester.tap(find.text('VIEW RESULT'));
        await tester.pumpAndSettle();
        expect(find.text(safety.name.toUpperCase()), findsOneWidget);
        expect(find.text('320.00'), findsOneWidget);
        expect(find.textContaining('DEMO MODE'), findsNothing);
        expect(history.records.values.single.status, safety);
        expect(history.records.values.single.sensorReading, 320.0);
        expect(history.attempts.length, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('start acceptance precedes countdown; timeout never saves', (
    tester,
  ) async {
    final start = Completer<http.Response>();
    final history = MemoryHistory();
    final sensor = Esp32AlcoholSensorService(
      testType: TestType.vehicle,
      esp32Service: Esp32Service(
        client: MockClient((request) async {
          if (request.method == 'POST') return start.future;
          return http.Response(jsonEncode(status(state: 'SAMPLING')), 200);
        }),
      ),
    );
    await tester.pumpWidget(
      AppSession(
        auth: FakeAuthService(userId: 'u'),
        profiles: DemoUserProfileRepository(),
        history: history,
        changes: SessionChanges(),
        child: MaterialApp(
          home: AlcoholTestScreen(
            testType: TestType.vehicle,
            sensorService: sensor,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('START TEST'));
    await tester.tap(find.text('START TEST'));
    await tester.pump();
    expect(find.text('CONNECTING...'), findsOneWidget);
    expect(find.text('Get Ready'), findsNothing);
    start.complete(
      http.Response('{"success":true,"message":"Vehicle test started"}', 200),
    );
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    for (var i = 0; i < 32; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('did not reach COMPLETED'), findsOneWidget);
    expect(find.text('VIEW RESULT'), findsNothing);
    expect(history.attempts, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
