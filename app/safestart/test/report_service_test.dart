import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/history_filter.dart';
import 'package:safestart/models/history_report.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/models/user_profile.dart';
import 'package:safestart/services/demo_test_history_repository.dart';
import 'package:safestart/services/report_service.dart';

String pdfText(List<int> bytes) {
  final raw = latin1.decode(bytes);
  final hex = RegExp(r'<([0-9A-Fa-f]+)>')
      .allMatches(raw)
      .map((m) {
        final value = m.group(1)!;
        if (value.length.isOdd) return '';
        return latin1.decode([
          for (var i = 0; i < value.length; i += 2)
            int.parse(value.substring(i, i + 2), radix: 16),
        ]);
      })
      .join(' ');
  // PDF text is positioned word by word; join literal strings for assertions.
  final words = RegExp(r'\(((?:\\.|[^\\)])*)\)')
      .allMatches(raw)
      .map((m) => m.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'))
      .join(' ');
  return '$raw $hex $words';
}

void main() {
  test(
    'stored report includes profile and filtered records without demo labels',
    () async {
      final data = await const DemoTestHistoryRepository().getResults();
      final report = HistoryReport(
        source: data.take(1).toList(),
        filter: HistoryFilter(
          referenceDate: data.first.timestamp,
          period: HistoryPeriod.daily,
        ),
        generatedAt: DateTime(2026, 10, 1),
        isDemo: false,
        profile: const UserProfile(
          fullName: 'Stored User',
          employeeId: 'STORED-001',
          email: 'test@example.com',
          userType: UserType.employee,
        ),
      );
      final text = pdfText(
        await const ReportService(compress: false).generate(report),
      );
      expect(text, contains('Stored User'));
      expect(text, contains('STORED-001'));
      expect(text, contains('SAVED PROTOTYPE SIMULATION RECORDS'));
      expect(text, isNot(contains('DEMO HISTORY')));
      expect(report.analytics.total, 1);
    },
  );
  test(
    'PDF contains title, disclaimer and only filtered demo table records',
    () async {
      final data = await const DemoTestHistoryRepository().getResults();
      final report = HistoryReport(
        source: data,
        filter: HistoryFilter(
          referenceDate: DateTime(2026, 10, 1),
          period: HistoryPeriod.daily,
          testType: TestType.vehicle,
        ),
        generatedAt: DateTime(2026, 10, 2, 10, 30),
      );
      expect(report.records.length, 1);
      expect(report.records.single.testType, TestType.vehicle);
      expect(report.analytics.total, 1);
      final bytes = await const ReportService(compress: false).generate(report);
      expect(bytes.length, greaterThan(1000));
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      final text = pdfText(bytes);
      expect(text, contains('SafeStart'));
      expect(text, contains(ReportService.disclaimer));
      expect(text, contains('0.08'));
      expect(text, isNot(contains('0.51')));
      expect(text, contains('DEMO HISTORY'));
      expect(text, contains('2026-10-01'));
    },
  );
  test(
    'Empty and multi-page reports generate without internet or platform APIs',
    () async {
      final data = await const DemoTestHistoryRepository().getResults();
      for (final source in [data, data.take(0).toList()]) {
        final report = HistoryReport(
          source: source,
          filter: HistoryFilter(
            referenceDate: DateTime(2026, 10, 1),
            customStart: DateTime(2026, 1, 1),
            customEnd: DateTime(2026, 12, 31),
          ),
          generatedAt: DateTime(2026, 10, 2),
        );
        final bytes = await const ReportService(compress: false)
            .generate(report);
        final text = pdfText(bytes);
        expect(bytes.length, greaterThan(1000));
        if (source.isEmpty) {
          expect(text, contains('No test records found for this period.'));
        } else {
          expect(report.records.length, 48);
          expect(
            RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
            greaterThan(1),
          );
        }
      }
    },
  );
}
