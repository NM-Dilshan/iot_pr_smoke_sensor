import 'alcohol_test_result.dart';
import 'history_analytics.dart';
import 'history_filter.dart';
import 'user_profile.dart';
import '../services/history_analytics_service.dart';

/// One immutable filtered snapshot shared by the report table and statistics.
class HistoryReport {
  HistoryReport({
    required List<AlcoholTestResult> source,
    required this.filter,
    required this.generatedAt,
    this.profile,
    this.isDemo = true,
  }) : records = filter.apply(source) {
    analytics = const HistoryAnalyticsService().calculate(records);
  }

  final HistoryFilter filter;
  final UserProfile? profile;
  final bool isDemo;
  final DateTime generatedAt;
  final List<AlcoholTestResult> records;
  late final HistoryAnalytics analytics;
}
