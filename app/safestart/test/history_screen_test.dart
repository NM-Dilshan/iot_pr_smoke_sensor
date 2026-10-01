import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:safestart/models/alcohol_test_result.dart';
import 'package:safestart/models/history_report.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/screens/history/history_screen.dart';
import 'package:safestart/screens/history/history_detail_sheet.dart';
import 'package:safestart/screens/history/report_preview_screen.dart';
import 'package:safestart/services/report_service.dart';
import 'package:safestart/services/test_history_repository.dart';
import 'package:safestart/theme/app_theme.dart';
import 'package:safestart/widgets/dashboard_stat_card.dart';
import 'package:safestart/widgets/history_record_card.dart';
import 'package:safestart/widgets/history_charts.dart';

class EmptyRepository implements TestHistoryRepository {
  @override
  Future<void> saveResult(String id, AlcoholTestResult result) async {}
  @override
  Future<List<AlcoholTestResult>> getResults() async => [];
}

class FailingRepository implements TestHistoryRepository {
  @override
  Future<void> saveResult(String id, AlcoholTestResult result) async {}
  @override
  Future<List<AlcoholTestResult>> getResults() async =>
      throw StateError('offline');
}

class CapturingReportService extends ReportService {
  HistoryReport? report;
  @override
  Future<Uint8List> generate(HistoryReport report) async {
    this.report = report;
    return Uint8List.fromList([37, 80, 68, 70, 45]);
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chip(WidgetTester tester, String label) =>
    tap(tester, find.widgetWithText(ChoiceChip, label));
int total(WidgetTester tester) => tester
    .widgetList<DashboardStatCard>(find.byType(DashboardStatCard))
    .firstWhere((card) => card.label == 'TOTAL TESTS')
    .value;

void main() {
  testWidgets(
    'Demo history filters update records, summary and graphs together',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const HistoryScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('DEMO DATA'), findsOneWidget);
      expect(total(tester), 14);
      expect(find.byType(HistoryRecordCard), findsNWidgets(14));
      expect(find.text('Weekly Alcohol Detection Trend'), findsOneWidget);
      expect(
        tester
            .widget<HistoryTrendChart>(find.byType(HistoryTrendChart))
            .points
            .length,
        7,
      );
      await chip(tester, 'Daily');
      expect(total(tester), 2);
      expect(find.byType(HistoryRecordCard), findsNWidgets(2));
      expect(
        tester
            .widget<HistoryTrendChart>(find.byType(HistoryTrendChart))
            .points
            .length,
        1,
      );
      await chip(tester, 'Monthly');
      expect(total(tester), 26);
      await chip(tester, 'Vehicle');
      expect(total(tester), 13);
      expect(
        tester
            .widgetList<HistoryRecordCard>(find.byType(HistoryRecordCard))
            .every((c) => c.record.testType == TestType.vehicle),
        isTrue,
      );
      expect(
        tester
            .widget<HistoryStatusChart>(find.byType(HistoryStatusChart))
            .analytics
            .total,
        13,
      );
      await chip(tester, 'Office');
      expect(total(tester), 13);
      expect(
        tester
            .widgetList<HistoryRecordCard>(find.byType(HistoryRecordCard))
            .every((c) => c.record.testType == TestType.office),
        isTrue,
      );
      await chip(tester, 'All');
      expect(total(tester), 26);
      await chip(tester, 'Weekly');
      expect(total(tester), 14);
      await tap(tester, find.byType(HistoryRecordCard).first);
      expect(find.byType(HistoryDetailSheet), findsOneWidget);
      expect(find.text('Prototype simulation record'), findsOneWidget);
      expect(find.text('Prototype Safety Classification'), findsOneWidget);
      expect(find.textContaining('BAC'), findsNothing);
      await tap(tester, find.text('CLOSE'));
    },
  );

  testWidgets(
    'Custom range is inclusive, affects report scope, and can be cleared',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const HistoryScreen()),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Select date range'));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '09/30/2026');
      await tester.enterText(find.byType(TextField).at(1), '10/01/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(total(tester), 4);
      expect(find.textContaining('Custom date range'), findsOneWidget);
      await tap(tester, find.text('Clear date range'));
      expect(total(tester), 14);
    },
  );

  testWidgets('Empty data stays finite and reset filters is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HistoryScreen(repository: EmptyRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(total(tester), 0);
    expect(find.text('No test records found for this period.'), findsOneWidget);
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('Infinity'), findsNothing);
    await chip(tester, 'Office');
    await tap(tester, find.text('CLEAR FILTERS'));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Weekly'))
          .selected,
      isTrue,
    );
  });

  testWidgets('Loading failure offers retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HistoryScreen(repository: FailingRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load history.'), findsOneWidget);
    await tap(tester, find.text('RETRY'));
    expect(find.text('Unable to load history.'), findsOneWidget);
  });

  testWidgets(
    'Generate report passes current filters to a preview with sharing enabled',
    (tester) async {
      const channel = MethodChannel('net.nfet.printing');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'printingInfo') {
              return {'canPrint': false, 'canShare': true, 'canRaster': false};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = CapturingReportService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HistoryScreen(reportService: service),
        ),
      );
      await tester.pumpAndSettle();
      await chip(tester, 'Daily');
      await chip(tester, 'Vehicle');
      await tap(tester, find.text('GENERATE REPORT'));
      expect(service.report!.records.length, 1);
      expect(service.report!.records.single.testType, TestType.vehicle);
      expect(find.byType(ReportPreviewScreen), findsOneWidget);
      expect(
        tester.widget<PdfPreview>(find.byType(PdfPreview)).allowSharing,
        isTrue,
      );
      expect(
        tester
            .widget<ReportPreviewScreen>(find.byType(ReportPreviewScreen))
            .bytes
            .length,
        5,
      );
    },
  );

  testWidgets('Narrow history and graphs support large text without overflow', (
    tester,
  ) async {
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
        home: const HistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await chip(tester, 'Monthly');
    await tester.ensureVisible(find.byType(HistoryStatusChart));
    await tester.pumpAndSettle();
    await tap(tester, find.byType(HistoryRecordCard).last);
    expect(find.byType(HistoryDetailSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
