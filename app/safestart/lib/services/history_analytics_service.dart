import '../models/alcohol_test_result.dart';
import '../models/history_analytics.dart';
import '../models/history_filter.dart';
import '../models/safety_status.dart';
import '../models/test_type.dart';

class HistoryAnalyticsService {
  const HistoryAnalyticsService();

  HistoryAnalytics calculate(List<AlcoholTestResult> results) {
    final counts = {for (final status in SafetyStatus.values) status: 0};
    final daily = <DateTime, List<double>>{};
    var sum = 0.0;
    var highest = 0.0;
    var vehicles = 0;
    for (final result in results) {
      counts[result.status] = counts[result.status]! + 1;
      sum += result.sensorReading;
      if (result.sensorReading > highest) highest = result.sensorReading;
      if (result.testType == TestType.vehicle) vehicles++;
      daily
          .putIfAbsent(historyDay(result.timestamp), () => [])
          .add(result.sensorReading);
    }
    final dates = daily.keys.toList()..sort();
    return HistoryAnalytics(
      total: results.length,
      counts: counts,
      averageReading: results.isEmpty ? 0 : sum / results.length,
      highestReading: highest,
      vehicleCount: vehicles,
      officeCount: results.length - vehicles,
      trend: [
        for (final date in dates)
          HistoryTrendPoint(
            date: date,
            averageReading:
                daily[date]!.reduce((a, b) => a + b) / daily[date]!.length,
          ),
      ],
    );
  }
}
