import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/screens/home/home_screen.dart';
import 'package:safestart/theme/app_theme.dart';
import 'package:safestart/widgets/dashboard_stat_card.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Demo dashboard keeps future actions on Home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
    );
    expect(find.text('Demo Mode'), findsOneWidget);
    expect(find.text('Not Connected'), findsOneWidget);
    expect(
      tester
          .widgetList<DashboardStatCard>(find.byType(DashboardStatCard))
          .map((card) => card.value),
      everyElement(0),
    );
    expect(find.text('DEMO / SAMPLE VALUES'), findsOneWidget);
    expect(find.text('No tests recorded yet'), findsOneWidget);
    await tapVisible(
      tester,
      find.widgetWithIcon(IconButton, Icons.notifications_outlined),
    );
    expect(
      find.text('Notifications will be available in a later step.'),
      findsOneWidget,
    );

    for (final label in ['START VEHICLE TEST', 'START OFFICE TEST']) {
      await tapVisible(tester, find.text(label));
      expect(
        find.text(
          label == 'START VEHICLE TEST'
              ? 'Vehicle Safety Test'
              : 'Office Safety Test',
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    }
    final actions = {
      'History': 'History will be implemented in a later step.',
      'Emergency Contact':
          'Emergency Contact will be implemented in a later step.',
      'Device Status':
          'ESP32 device is not connected. SafeStart is currently in Demo Mode.',
    };
    for (final action in actions.entries) {
      await tapVisible(tester, find.widgetWithText(ListTile, action.key));
      expect(find.text(action.value), findsOneWidget);
    }
    for (final label in ['History', 'Notifications', 'Settings']) {
      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      expect(find.text('$label will be implemented later.'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    }
    await tapVisible(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(1000, 800)]) {
    testWidgets('Dashboard scrolls without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
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
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('START OFFICE TEST'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(ListTile, 'Device Status'));
      expect(tester.takeException(), isNull);
    });
  }
}
