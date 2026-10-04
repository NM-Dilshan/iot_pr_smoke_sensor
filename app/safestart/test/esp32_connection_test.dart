import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:safestart/services/esp32_connection.dart';
import 'package:safestart/services/esp32_service.dart';
import 'package:safestart/services/esp32_alcohol_sensor_service.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/screens/home/home_screen.dart';
import 'package:safestart/widgets/device_connection_view.dart';

Map<String, dynamic> status({
  String state = 'IDLE',
  String result = 'NOT_TESTED',
}) => {
  'vehicleReading': 94,
  'vehicleStatus': 'SAFE',
  'vehicleTestState': state,
  'vehicleTestResult': result,
  'vehicleResultReading': 107,
  'vehicleTestActive': state != 'IDLE' && state != 'COMPLETED',
  'officeReading': 762,
  'officeStatus': 'SAFE',
  'officeTestState': state,
  'officeTestResult': result,
  'officeResultReading': 762,
  'officeTestActive': state != 'IDLE' && state != 'COMPLETED',
  'gate': 'CLOSED',
  'wifi': 'CONNECTED',
};
http.Response good({String state = 'IDLE', String result = 'NOT_TESTED'}) =>
    http.Response(jsonEncode(status(state: state, result: result)), 200);
const realIdleJson =
    '{"vehicleReading":162,"vehicleStatus":"SAFE","vehicleTestState":"IDLE","vehicleTestResult":"NOT_TESTED","vehicleResultReading":0,"vehicleTestActive":false,"officeReading":821,"officeStatus":"SAFE","officeTestState":"IDLE","officeTestResult":"NOT_TESTED","officeResultReading":0,"officeTestActive":false,"gate":"CLOSED","wifi":"CONNECTED"}';

void main() {
  test('exact phone status verifies IDLE, NOT_TESTED and zero results', () {
    final parsed = Esp32Connection.verify(http.Response(realIdleJson, 200));
    expect(parsed.vehicleReading, 162);
    expect(parsed.officeReading, 821);
    expect(parsed.vehicleTestState, 'IDLE');
    expect(parsed.vehicleTestResult, 'NOT_TESTED');
    expect(parsed.vehicleResultReading, 0);
    expect(parsed.officeTestResult, 'NOT_TESTED');
    expect(parsed.officeResultReading, 0);
    expect(parsed.gate, 'CLOSED');
  });

  test(
    'direct hostname verifies before native discovery and routes both starts',
    () async {
      final calls = <String>[];
      final connection = Esp32Connection(
        resolveHostname: () async => throw StateError('native should not run'),
        localCandidates: () async => throw StateError('scan should not run'),
        request: (uri, method, _) async {
          expect(uri.host, Esp32Connection.hostname);
          calls.add('$method ${uri.path}');
          return http.Response(
            method == 'GET' ? realIdleJson : '{"success":true}',
            200,
          );
        },
      );
      addTearDown(connection.dispose);
      await connection.fetchStatus();
      expect(connection.activeAddress.toString(), 'http://safestart.local');
      expect(calls, ['GET /status']);
      final service = Esp32Service(connection: connection);
      await service.startVehicleTest();
      await service.startOfficeTest();
      expect(calls, [
        'GET /status',
        'GET /status',
        'POST /vehicle/start',
        'GET /status',
        'POST /office/start',
      ]);
    },
  );

  test(
    'Dart hostname socket failure uses native IPv4 after IPv6 and link-local',
    () async {
      const channel = MethodChannel('safestart/network');
      final nativeCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nativeCalls.add(call.method);
            return ['fe80::1234', '2001:db8::1', '169.254.1.2', '192.168.1.7'];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final requests = <String>[];
      final connection = Esp32Connection(
        request: (uri, method, _) async {
          expect(method, 'GET');
          requests.add(uri.host);
          if (uri.host == Esp32Connection.hostname) {
            throw const SocketException('Failed host lookup');
          }
          return http.Response(realIdleJson, 200);
        },
      );
      addTearDown(connection.dispose);
      await connection.fetchStatus();
      expect(connection.activeAddress.toString(), 'http://192.168.1.7');
      expect(requests, ['safestart.local', '192.168.1.7']);
      expect(nativeCalls, ['resolveHostname']);
    },
  );

  test(
    'failed cached hostname rediscovery switches to verified IPv4',
    () async {
      var hostnameOnline = true;
      final requests = <String>[];
      final connection = Esp32Connection(
        resolveHostname: () async => ['192.168.1.7'],
        localCandidates: () async => [],
        request: (uri, method, _) async {
          expect(method, 'GET');
          requests.add(uri.host);
          if (!hostnameOnline && uri.host == Esp32Connection.hostname) {
            throw const SocketException('Network changed');
          }
          return http.Response(realIdleJson, 200);
        },
      );
      addTearDown(connection.dispose);
      await connection.fetchStatus();
      hostnameOnline = false;
      await connection.fetchStatus();
      await connection.fetchStatus();
      expect(connection.activeAddress.toString(), 'http://192.168.1.7');
      expect(requests, [
        'safestart.local',
        'safestart.local',
        '192.168.1.7',
        '192.168.1.7',
      ]);
    },
  );

  for (final transition in [
    ('IDLE', 'NOT_TESTED'),
    ('COUNTDOWN', 'PENDING'),
    ('SAMPLING', 'PENDING'),
    ('COMPLETED', 'SAFE'),
  ]) {
    test('verified ${transition.$1}/${transition.$2} is connected', () async {
      final connection = Esp32Connection(
        resolveHostname: () async => ['192.168.1.7'],
        localCandidates: () async =>
            throw StateError('fallback should not run'),
        request: (uri, method, _) async {
          expect(uri.path, '/status');
          expect(method, 'GET');
          return good(state: transition.$1, result: transition.$2);
        },
      );
      await connection.fetchStatus();
      expect(connection.connected, true);
      expect(connection.activeAddress!.host, Esp32Connection.hostname);
      connection.dispose();
    });
  }
  test(
    'verified address is cached and only loss triggers hostname rediscovery',
    () async {
      var hostnameCalls = 0;
      var host = '192.168.1.7';
      var online = true;
      final methods = <String>[];
      final states = <bool>[];
      final connection = Esp32Connection(
        resolveHostname: () async {
          hostnameCalls++;
          return [host];
        },
        localCandidates: () async => [],
        request: (uri, method, _) async {
          methods.add(method);
          if (!online || uri.host != host) throw StateError('unreachable');
          return good(state: 'COMPLETED', result: 'DANGER');
        },
      );
      connection.addListener(() => states.add(connection.connected));
      await connection.fetchStatus();
      await connection.fetchStatus();
      expect(hostnameCalls, 1);
      host = '172.20.10.3';
      await connection.fetchStatus();
      expect(connection.activeAddress!.host, host);
      expect(states, [true, false, true]);
      expect(hostnameCalls, 2);
      expect(
        methods.every((method) => method == 'GET'),
        true,
      ); // DANGER discovery never starts tests/SMS.
      connection.dispose();
    },
  );
  test('hostname failure falls back only to private candidates and rejects random HTTP servers', () async {
    final requests = <String>[];
    final connection = Esp32Connection(
      resolveHostname: () async => throw StateError('no mDNS'),
      localCandidates: () async => [
        '8.8.8.8',
        '127.0.0.1',
        '192.168.43.2',
        '192.168.43.9',
      ],
      request: (uri, method, _) async {
        expect(method, 'GET');
        expect(uri.path, '/status');
        requests.add(uri.host);
        return uri.host.endsWith('.9')
            ? good()
            : http.Response('{"server":"random"}', 200);
      },
    );
    await connection.fetchStatus();
    expect(connection.activeAddress!.host, '192.168.43.9');
    expect(requests, contains('192.168.43.2'));
    expect(requests, isNot(contains('8.8.8.8')));
    expect(requests, isNot(contains('127.0.0.1')));
    connection.dispose();
  });
  test('malformed and missing identity fields never connect', () async {
    for (final body in [
      'broken',
      '[]',
      '{}',
      jsonEncode({...status()}..remove('officeTestActive')),
    ]) {
      final connection = Esp32Connection(
        resolveHostname: () async => ['192.168.1.3'],
        localCandidates: () async => [],
        request: (_, _, _) async => http.Response(body, 200),
      );
      await expectLater(
        connection.fetchStatus(),
        throwsA(isA<Esp32Exception>()),
      );
      expect(connection.connected, false);
      expect(connection.activeAddress, isNull);
      connection.dispose();
    }
  });
  test(
    'backoff avoids subnet scans every poll and device returns without restart',
    () async {
      var now = DateTime(2026, 10, 3);
      var scans = 0;
      var online = false;
      final connection = Esp32Connection(
        now: () => now,
        resolveHostname: () async => [],
        localCandidates: () async {
          scans++;
          return ['192.168.137.12'];
        },
        request: (uri, _, _) async {
          if (uri.host == Esp32Connection.hostname) {
            throw const SocketException('Hostname unavailable');
          }
          if (!online) throw StateError('offline');
          return good();
        },
      );
      await expectLater(
        connection.fetchStatus(),
        throwsA(isA<Esp32Exception>()),
      );
      await expectLater(
        connection.fetchStatus(),
        throwsA(isA<Esp32Exception>()),
      );
      expect(scans, 1);
      now = now.add(const Duration(seconds: 10));
      await expectLater(
        connection.fetchStatus(),
        throwsA(isA<Esp32Exception>()),
      );
      expect(scans, 2);
      now = now.add(const Duration(seconds: 20));
      online = true;
      await connection.fetchStatus();
      expect(connection.connected, true);
      expect(scans, 3);
      connection.dispose();
    },
  );
  test('concurrent callers share one discovery', () async {
    final resolution = Completer<List<String>>();
    var resolutions = 0, requests = 0;
    final connection = Esp32Connection(
      resolveHostname: () {
        resolutions++;
        return resolution.future;
      },
      localCandidates: () async => [],
      request: (uri, _, _) async {
        if (uri.host == Esp32Connection.hostname) {
          throw const SocketException('Hostname unavailable');
        }
        requests++;
        return good();
      },
    );
    final first = connection.fetchStatus(), second = connection.fetchStatus();
    resolution.complete(['192.168.1.9']);
    await Future.wait([first, second]);
    expect(resolutions, 1);
    expect(requests, 1);
    connection.dispose();
  });
  test(
    'Vehicle and Office POST share discovered URL and remain authoritative',
    () async {
      final posts = <String>[];
      final connection = Esp32Connection(
        resolveHostname: () async => ['192.168.43.45'],
        localCandidates: () async => [],
        request: (uri, method, _) async {
          if (uri.host == Esp32Connection.hostname) {
            throw const SocketException('Hostname unavailable');
          }
          expect(uri.host, '192.168.43.45');
          if (method == 'POST') {
            posts.add(uri.path);
            return http.Response('{"success":true}', 200);
          }
          return good(state: 'COMPLETED', result: 'SAFE');
        },
      );
      final service = Esp32Service(connection: connection);
      await service.startVehicleTest();
      await service.startOfficeTest();
      expect(posts, ['/vehicle/start', '/office/start']);
      final vehicle = (await Esp32AlcoholSensorService(
        testType: TestType.vehicle,
        esp32Service: service,
      ).pollVehicleResult())!;
      final office = (await Esp32AlcoholSensorService(
        testType: TestType.office,
        esp32Service: service,
      ).pollOfficeResult())!;
      expect(vehicle.status, SafetyStatus.safe);
      expect(vehicle.sensorReading, 107.0);
      expect(office.status, SafetyStatus.safe);
      expect(office.sensorReading, 762.0);
      connection.dispose();
    },
  );
  test('uncertain POST failure is not replayed during rediscovery', () async {
    var posts = 0;
    final connection = Esp32Connection(
      resolveHostname: () async => ['192.168.1.2'],
      localCandidates: () async => [],
      request: (_, method, _) async {
        if (method == 'POST') {
          posts++;
          throw StateError('lost acknowledgement');
        }
        return good();
      },
    );
    await expectLater(
      Esp32Service(connection: connection).startVehicleTest(),
      throwsA(isA<Esp32Exception>()),
    );
    expect(connection.connected, false);
    await connection.fetchStatus();
    expect(posts, 1);
    connection.dispose();
  });
  test('Android bridge resolves hostname and supplies current candidates without packages', () async {
    const channel = MethodChannel('safestart/network');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'resolveHostname'
              ? ['8.8.8.8']
              : ['192.168.43.23'];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final connection = Esp32Connection(
      request: (uri, method, _) async {
        if (uri.host == Esp32Connection.hostname) {
          throw const SocketException('Hostname unavailable');
        }
        expect(uri.host, '192.168.43.23');
        expect(method, 'GET');
        return good();
      },
    );
    await connection.fetchStatus();
    expect(calls, ['resolveHostname', 'localCandidates']);
    connection.dispose();
  });
  testWidgets(
    'Dashboard online/offline/recovery, rebuild and lifecycle share a single monitor',
    (tester) async {
      var online = true, requests = 0;
      final connection = Esp32Connection(
        resolveHostname: () async => ['192.168.1.8'],
        localCandidates: () async => [],
        now: tester.binding.clock.now,
        request: (_, method, _) async {
          requests++;
          expect(method, 'GET');
          if (!online) throw StateError('offline');
          return good();
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(connection: connection)),
      );
      await tester.pumpAndSettle();
      expect(find.text('ESP32 Online'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(requests, 1);
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(connection: connection)),
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(requests, 2);
      online = false;
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
      expect(find.text('ESP32 Offline'), findsOneWidget);
      expect(find.text('Not Connected'), findsOneWidget);
      online = true;
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text('ESP32 Online'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = requests;
      await tester.pump(const Duration(seconds: 20));
      expect(requests, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests, paused + 1);
      await tester.pumpWidget(const SizedBox());
      final disposed = requests;
      await tester.pump(const Duration(seconds: 20));
      expect(requests, disposed);
      connection.dispose();
    },
  );
  testWidgets('hidden route stops monitoring and returning restarts one loop', (
    tester,
  ) async {
    var requests = 0;
    final connection = Esp32Connection(
      resolveHostname: () async => ['192.168.1.8'],
      localCandidates: () async => [],
      request: (_, _, _) async {
        requests++;
        return good();
      },
    );
    var enabled = true;
    Widget app() => MaterialApp(
      home: TickerMode(
        enabled: enabled,
        child: DeviceConnectionView(
          connection: connection,
          builder: (context, device) =>
              Text(device.connected ? 'Connected' : 'Offline'),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    enabled = false;
    await tester.pumpWidget(app());
    await tester.pump();
    final hidden = requests;
    await tester.pump(const Duration(seconds: 20));
    expect(requests, hidden);
    enabled = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(requests, hidden + 1);
    await tester.pumpWidget(const SizedBox());
    connection.dispose();
  });
  testWidgets(
    'unresolved discovery is cancelled on route disposal without a timeout leak',
    (tester) async {
      final resolution = Completer<List<String>>();
      var requests = 0;
      final connection = Esp32Connection(
        resolveHostname: () => resolution.future,
        localCandidates: () async => ['192.168.1.8'],
        request: (uri, _, _) async {
          if (uri.host == Esp32Connection.hostname) {
            throw const SocketException('Hostname unavailable');
          }
          requests++;
          return good();
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceConnectionView(
            connection: connection,
            builder: (context, device) => const Text('Dashboard'),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(requests, 0);
      resolution.complete(['192.168.1.8']);
      await tester.pump();
      expect(requests, 0);
      connection.dispose();
    },
  );
  testWidgets(
    'two status displays share one monitor and completed DANGER discovery never sends SMS',
    (tester) async {
      const sms = MethodChannel('safestart/emergency_sms');
      var smsCalls = 0, probes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sms, (_) async {
            smsCalls++;
            return {'status': 'sent'};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(sms, null),
      );
      final connection = Esp32Connection(
        resolveHostname: () async => ['192.168.1.8'],
        localCandidates: () async => [],
        request: (uri, method, _) async {
          probes++;
          expect(method, 'GET');
          expect(uri.path, '/status');
          return good(state: 'COMPLETED', result: 'DANGER');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              DeviceConnectionView(
                connection: connection,
                builder: (context, device) => Text('Home: ${device.connected}'),
              ),
              DeviceConnectionView(
                connection: connection,
                builder: (context, device) =>
                    Text('Settings: ${device.connected}'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(probes, 1);
      expect(smsCalls, 0);
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(probes, 2);
      expect(smsCalls, 0);
      await tester.pumpWidget(const SizedBox());
      connection.dispose();
    },
  );
}
