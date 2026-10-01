import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/screens/test/alcohol_test_screen.dart';
import 'package:safestart/services/alcohol_sensor_service.dart';
import 'package:safestart/services/mock_alcohol_sensor_service.dart';
import 'package:safestart/theme/app_theme.dart';

class PendingSensor implements AlcoholSensorService {
  final result = Completer<double>();
  int calls = 0;
  @override
  Future<double> readAlcoholLevel() {
    calls++;
    return result.future;
  }
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> tick(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> open(WidgetTester tester, AlcoholSensorService service) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlcoholTestScreen(
                  testType: TestType.vehicle,
                  sensorService: service,
                ),
              ),
            ),
            child: const Text('Open test'),
          ),
        ),
      ),
    ),
  );
  await tap(tester, 'Open test');
  await tester.pumpAndSettle();
}

void main() {
  test('Mock scenarios and configured values are deterministic', () async {
    final values = <double>[];
    for (final scenario in MockSensorScenario.values) {
      final service = MockAlcoholSensorService.scenario(scenario);
      final value = await service.readAlcoholLevel();
      expect(await service.readAlcoholLevel(), value);
      values.add(value);
    }
    expect(values, [0.02, 0.18, 0.35]);
    expect(
      await const MockAlcoholSensorService(simulatedReading: 0.27)
          .readAlcoholLevel(),
      0.27,
    );
  });

  testWidgets('Countdown, sampling, injected reading, result and retest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sensor = PendingSensor();
    await open(tester, sensor);
    expect(find.text('Ready to Test'), findsOneWidget);
    await tap(tester, 'START TEST');
    expect(find.text('Get Ready'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tick(tester, 1);
    expect(find.text('2'), findsOneWidget);
    await tick(tester, 1);
    expect(find.text('1'), findsOneWidget);
    expect(sensor.calls, 0);
    await tick(tester, 1);
    expect(find.text('BLOW NOW'), findsOneWidget);
    for (var i = 1; i <= 5; i++) {
      await tick(tester, 1);
      expect(find.text('${i * 20}%'), findsOneWidget);
      if (i < 5) expect(sensor.calls, 0);
    }
    expect(sensor.calls, 1);
    sensor.result.complete(0.27);
    await tester.pumpAndSettle();
    expect(find.text('Sample Collected'), findsOneWidget);
    expect(find.text('0.27'), findsOneWidget);
    await tap(tester, 'VIEW RESULT');
    await tester.pumpAndSettle();
    expect(find.text('Prototype Safety Classification'), findsOneWidget);
    expect(find.text('CAUTION'), findsOneWidget);
    expect(find.text('0.27'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, 'RETEST');
    expect(find.text('Ready to Test'), findsOneWidget);
    expect(find.text('0.27'), findsNothing);
    await tap(tester, 'START TEST');
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tick(tester, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back confirms cancellation and keep testing preserves the run', (
    tester,
  ) async {
    await open(tester, const MockAlcoholSensorService());
    await tap(tester, 'START TEST');
    await tick(tester, 3);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Cancel current test?'), findsOneWidget);
    await tap(tester, 'KEEP TESTING');
    await tester.pumpAndSettle();
    expect(find.text('BLOW NOW'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('CANCEL TEST'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open test'), findsOneWidget);
    await tick(tester, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disposed sampling ignores a late service completion', (
    tester,
  ) async {
    final sensor = PendingSensor();
    await open(tester, sensor);
    await tap(tester, 'START TEST');
    await tick(tester, 8);
    expect(sensor.calls, 1);
    await tester.pumpWidget(const SizedBox());
    sensor.result.complete(0.35);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sampling timer is disposed before a reading is requested', (
    tester,
  ) async {
    final sensor = PendingSensor();
    await open(tester, sensor);
    await tap(tester, 'START TEST');
    await tick(tester, 4);
    await tester.pumpWidget(const SizedBox());
    await tick(tester, 10);
    expect(sensor.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Service failure returns to ready without a fabricated value', (
    tester,
  ) async {
    final sensor = PendingSensor();
    await open(tester, sensor);
    await tap(tester, 'START TEST');
    await tick(tester, 8);
    sensor.result.completeError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to Test'), findsOneWidget);
    expect(
      find.text('Unable to collect the simulated reading. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Sample Collected'), findsNothing);
  });
}
