import 'alcohol_test_result.dart';
import 'test_type.dart';

enum HistoryPeriod { daily, weekly, monthly }

DateTime historyDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String historyDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String historyTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// Rolling calendar-day windows ending on referenceDate. Custom range overrides
/// the period, with inclusive start/end days interpreted in local time.
class HistoryFilter {
  const HistoryFilter({
    this.period = HistoryPeriod.weekly,
    this.testType,
    required this.referenceDate,
    this.customStart,
    this.customEnd,
  }) : assert((customStart == null) == (customEnd == null));

  final HistoryPeriod period;
  final TestType? testType;
  final DateTime referenceDate;
  final DateTime? customStart;
  final DateTime? customEnd;

  bool get isCustom => customStart != null;
  DateTime get end => historyDay(customEnd ?? referenceDate);
  DateTime get start {
    if (customStart != null) return historyDay(customStart!);
    final days = switch (period) {
      HistoryPeriod.daily => 1,
      HistoryPeriod.weekly => 7,
      HistoryPeriod.monthly => 30,
    };
    return DateTime(end.year, end.month, end.day - days + 1);
  }

  String get periodLabel => isCustom
      ? 'Custom date range'
      : switch (period) {
          HistoryPeriod.daily => 'Daily (1 day)',
          HistoryPeriod.weekly => 'Weekly (7 days)',
          HistoryPeriod.monthly => 'Monthly (30 days)',
        };
  String get typeLabel => testType?.label ?? 'All';
  String get rangeLabel => '${historyDate(start)} to ${historyDate(end)}';

  List<AlcoholTestResult> apply(Iterable<AlcoholTestResult> results) {
    final exclusiveEnd = DateTime(end.year, end.month, end.day + 1);
    final filtered =
        results
            .where(
              (result) =>
                  (testType == null || result.testType == testType) &&
                  !result.timestamp.toLocal().isBefore(start) &&
                  result.timestamp.toLocal().isBefore(exclusiveEnd),
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(filtered);
  }
}
