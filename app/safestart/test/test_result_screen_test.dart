import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/alcohol_test_result.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/screens/home/home_screen.dart';
import 'package:safestart/screens/test/alcohol_test_screen.dart';
import 'package:safestart/screens/test/test_preparation_screen.dart';
import 'package:safestart/screens/test/test_result_screen.dart';
import 'package:safestart/theme/app_theme.dart';
import 'package:safestart/services/mock_alcohol_sensor_service.dart';

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  for (final type in TestType.values) {
    for (final status in SafetyStatus.values) {
      testWidgets('${type.label} ${status.name} result wording and details', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final reading = switch (status) {
          SafetyStatus.safe => 0.18,
          SafetyStatus.caution => 0.30,
          SafetyStatus.danger => 0.50,
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: TestResultScreen(
              result: AlcoholTestResult(
                testType: type,
                sensorReading: reading,
                status: status,
                timestamp: DateTime(2026, 10, 1, 9, 5),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(status.name.toUpperCase()), findsOneWidget);
        expect(find.text(reading.toStringAsFixed(2)), findsOneWidget);
        expect(find.text('Test Type: ${type.label}'), findsOneWidget);
        expect(find.textContaining('Date:'), findsOneWidget);
        expect(find.textContaining('Time:'), findsOneWidget);
        expect(find.text('Prototype Safety Classification'), findsOneWidget);
        expect(
          find.text('Result not saved — cloud storage will be added later.'),
          findsOneWidget,
        );
        final expected = switch ((type, status)) {
          (TestType.vehicle, SafetyStatus.safe) =>
            'No restriction triggered by the prototype.',
          (TestType.vehicle, SafetyStatus.caution) =>
            'Proceeding is not recommended until the test is repeated.',
          (TestType.vehicle, SafetyStatus.danger) =>
            'Vehicle access would be restricted in the final SafeStart system.',
          (TestType.office, SafetyStatus.safe) =>
            'No alert triggered by the prototype.',
          (TestType.office, SafetyStatus.caution) =>
            'A repeat screening may be appropriate.',
          (TestType.office, SafetyStatus.danger) => 'High sensor reading detected by the prototype workplace screening.',
        };
        expect(find.text(expected), findsOneWidget);
        if (type == TestType.office) {
          expect(find.textContaining('Vehicle'), findsNothing);
          expect(find.text('Emergency Contact Alert'), findsNothing);
          if (status == SafetyStatus.danger) {
            expect(find.text('Office Safety Alert'), findsOneWidget);
          }
        } else if (status == SafetyStatus.danger) {
          expect(find.text('Vehicle Safety Alert'), findsOneWidget);
          expect(find.text('No emergency contact configured.'), findsOneWidget);
        }
        await tester.ensureVisible(find.text('DONE'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '${type.label} result retest is fresh and DONE returns to original Home',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
        );
        final home = tester.element(find.byType(HomeScreen));
        await tap(tester, 'START ${type.label.toUpperCase()} TEST');
        await tap(tester, 'I have read the instructions and I am ready.');
        await tap(tester, 'CONTINUE TO TEST');
        final testContext = tester.element(find.byType(AlcoholTestScreen));
        Navigator.of(testContext).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => AlcoholTestScreen(
              testType: type,
              sensorService: const MockAlcoholSensorService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'START TEST');
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pumpAndSettle();
        await tap(tester, 'VIEW RESULT');
        final result = tester
            .widget<TestResultScreen>(find.byType(TestResultScreen))
            .result;
        expect(result.testType, type);
        expect(result.sensorReading, 0.18);
        expect(result.status, SafetyStatus.safe);
        expect(DateTime.now().difference(result.timestamp).inMinutes, 0);
        await tap(tester, 'RETEST');
        expect(
          find.byType(TestResultScreen, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.byType(AlcoholTestScreen, skipOffstage: false),
          findsNothing,
        );
        expect(
          tester
              .widget<TestPreparationScreen>(find.byType(TestPreparationScreen))
              .testType,
          type,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'CONTINUE TO TEST'),
              )
              .onPressed,
          isNull,
        );
        await tap(tester, 'I have read the instructions and I am ready.');
        await tap(tester, 'CONTINUE TO TEST');
        expect(find.text('Ready to Test'), findsOneWidget);
        expect(find.text('0.18'), findsNothing);
        expect(find.text('VIEW RESULT'), findsNothing);
        Navigator.of(tester.element(find.byType(AlcoholTestScreen)))
            .pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => AlcoholTestScreen(
                  testType: type,
                  sensorService: const MockAlcoholSensorService(),
                ),
              ),
            );
        await tester.pumpAndSettle();
        await tap(tester, 'START TEST');
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pumpAndSettle();
        await tap(tester, 'VIEW RESULT');
        await tap(tester, 'DONE');
        expect(tester.element(find.byType(HomeScreen)), same(home));
        expect(
          find.byType(TestResultScreen, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.byType(TestPreparationScreen, skipOffstage: false),
          findsNothing,
        );
        expect(find.text('No tests recorded yet'), findsOneWidget);
      },
    );
  }
}
