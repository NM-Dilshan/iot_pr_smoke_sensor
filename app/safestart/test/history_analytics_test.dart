import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/alcohol_test_result.dart';
import 'package:safestart/models/history_filter.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/services/alcohol_classification_service.dart';
import 'package:safestart/services/demo_test_history_repository.dart';
import 'package:safestart/services/history_analytics_service.dart';

void main() {
  final day = DateTime(2026, 10, 1);
  test('48 deterministic records span types, statuses and months', () async {
    final records = await const DemoTestHistoryRepository().getResults();
    final repeated = await const DemoTestHistoryRepository().getResults();
    expect(records.length, 48);
    expect(
      records.map((r) => r.timestamp),
      orderedEquals(repeated.map((r) => r.timestamp)),
    );
    expect(
      records.map((r) => r.sensorReading),
      orderedEquals(repeated.map((r) => r.sensorReading)),
    );
    expect(
      records.map((r) => r.timestamp.month).toSet().length,
      greaterThan(3),
    );
    expect(records.map((r) => r.status).toSet(), SafetyStatus.values.toSet());
    for (final record in records) {
      expect(
        record.status,
        const AlcoholClassificationService().classify(record.sensorReading),
      );
    }
    for (final type in TestType.values) {
      expect(records.where((r) => r.testType == type).length, 24);
    }
  });
  test('Periods and all/type filters select the actual records', () async {
    final records = await const DemoTestHistoryRepository().getResults();
    for (final entry in {
      HistoryPeriod.daily: 2,
      HistoryPeriod.weekly: 14,
      HistoryPeriod.monthly: 26,
    }.entries) {
      final all = HistoryFilter(
        referenceDate: day,
        period: entry.key,
      ).apply(records);
      expect(all.length, entry.value);
      for (final type in TestType.values) {
        final filtered = HistoryFilter(
          referenceDate: day,
          period: entry.key,
          testType: type,
        ).apply(records);
        expect(filtered.length, entry.value ~/ 2);
        expect(filtered.every((r) => r.testType == type), isTrue);
      }
    }
  });
  test('Custom range overrides period and includes the entire last day', () {
    AlcoholTestResult record(DateTime time) => AlcoholTestResult(
      testType: TestType.vehicle,
      sensorReading: 0.1,
      status: SafetyStatus.safe,
      timestamp: time,
    );
    final records = [
      record(DateTime(2026, 9, 1)),
      record(DateTime(2026, 9, 2, 23, 59, 59)),
      record(DateTime(2026, 9, 3)),
      record(DateTime(2026, 8, 31, 23, 59)),
    ];
    final filter = HistoryFilter(
      referenceDate: day,
      period: HistoryPeriod.daily,
      customStart: DateTime(2026, 9, 1),
      customEnd: DateTime(2026, 9, 2),
    );
    expect(filter.apply(records).length, 2);
    expect(filter.periodLabel, 'Custom date range');
  });
  test('Analytics computes counts, percentages, readings and daily trend', () {
    final data = [
      AlcoholTestResult(
        testType: TestType.vehicle,
        sensorReading: 0.1,
        status: SafetyStatus.safe,
        timestamp: day,
      ),
      AlcoholTestResult(
        testType: TestType.office,
        sensorReading: 0.3,
        status: SafetyStatus.caution,
        timestamp: day,
      ),
      AlcoholTestResult(
        testType: TestType.vehicle,
        sensorReading: 0.5,
        status: SafetyStatus.danger,
        timestamp: DateTime(2026, 9, 30),
      ),
    ];
    final a = const HistoryAnalyticsService().calculate(data);
    expect(a.total, 3);
    for (final status in SafetyStatus.values) {
      expect(a.count(status), 1);
      expect(a.percentage(status), closeTo(100 / 3, 0.0001));
    }
    expect(a.averageReading, closeTo(0.3, 0.0001));
    expect(a.highestReading, 0.5);
    expect(a.vehicleCount, 2);
    expect(a.officeCount, 1);
    expect(a.trend.length, 2);
    expect(a.trend.first.date, DateTime(2026, 9, 30));
    expect(a.trend.last.averageReading, closeTo(0.2, 0.0001));
  });
  test(
    'Empty analytics has finite zero values and no invented trend points',
    () {
      final a = const HistoryAnalyticsService().calculate([]);
      expect(a.total, 0);
      expect(a.averageReading, 0);
      expect(a.highestReading, 0);
      expect(a.vehicleCount, 0);
      expect(a.officeCount, 0);
      expect(a.trend, isEmpty);
      for (final status in SafetyStatus.values) {
        expect(a.count(status), 0);
        expect(a.percentage(status), 0);
      }
    },
  );
}
