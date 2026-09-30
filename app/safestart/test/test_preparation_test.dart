import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/screens/home/home_screen.dart';
import 'package:safestart/screens/test/test_preparation_screen.dart';
import 'package:safestart/screens/test/test_selection_screen.dart';
import 'package:safestart/theme/app_theme.dart';
import 'package:safestart/widgets/instruction_step.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final type in TestType.values) {
    testWidgets(
      '${type.label} preparation requires readiness and never creates a result',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        );
        await tapVisible(
          tester,
          find.text('START ${type.label.toUpperCase()} TEST'),
        );
        expect(
          tester
              .widget<TestPreparationScreen>(find.byType(TestPreparationScreen))
              .testType,
          type,
        );
        expect(find.text('${type.label} Safety Test'), findsOneWidget);
        expect(
          find.text(
            type == TestType.vehicle
                ? 'Prepare for your alcohol breath test'
                : 'Prepare for workplace alcohol screening',
          ),
          findsOneWidget,
        );
        expect(find.byType(InstructionStep), findsNWidgets(5));
        expect(
          find.text(
            type == TestType.vehicle
                ? 'Make sure you are not eating or drinking.'
                : 'Ensure the SafeStart device is ready.',
          ),
          findsOneWidget,
        );
        expect(find.text('Demo Mode / Not Connected'), findsOneWidget);
        final button = find.widgetWithText(ElevatedButton, 'CONTINUE TO TEST');
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        await tapVisible(tester, find.byType(CheckboxListTile));
        expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
        await tapVisible(tester, find.byType(CheckboxListTile));
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        await tapVisible(tester, find.byType(CheckboxListTile));
        await tapVisible(tester, button);
        expect(find.text('${type.label} Alcohol Test'), findsOneWidget);
        expect(find.text('Test Type: ${type.label}'), findsOneWidget);
        expect(find.text('Ready to Test'), findsOneWidget);
        expect(find.text('Using simulated sensor data'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('No tests recorded yet'), findsOneWidget);
        await tapVisible(
          tester,
          find.text('START ${type.label.toUpperCase()} TEST'),
        );
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Selection passes ${type.label} and back navigation returns to Home',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
        );
        await tapVisible(tester, find.text('Choose test type'));
        expect(find.byType(TestSelectionScreen), findsOneWidget);
        await tapVisible(
          tester,
          find.text('SELECT ${type.label.toUpperCase()} TEST'),
        );
        expect(
          tester
              .widget<TestPreparationScreen>(find.byType(TestPreparationScreen))
              .testType,
          type,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(TestSelectionScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
