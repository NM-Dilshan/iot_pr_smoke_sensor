import 'safety_status.dart';

class HistoryTrendPoint {
  const HistoryTrendPoint({required this.date, required this.averageReading});
  final DateTime date;
  final double averageReading;
}

class HistoryAnalytics {
  HistoryAnalytics({
    required this.total,
    required Map<SafetyStatus, int> counts,
    required this.averageReading,
    required this.highestReading,
    required this.vehicleCount,
    required this.officeCount,
    required List<HistoryTrendPoint> trend,
  }) : counts = Map.unmodifiable(counts),
       trend = List.unmodifiable(trend);

  final int total;
  final Map<SafetyStatus, int> counts;
  final double averageReading;
  final double highestReading;
  final int vehicleCount;
  final int officeCount;
  final List<HistoryTrendPoint> trend;

  int count(SafetyStatus status) => counts[status] ?? 0;
  double percentage(SafetyStatus status) =>
      total == 0 ? 0 : count(status) * 100 / total;
}
