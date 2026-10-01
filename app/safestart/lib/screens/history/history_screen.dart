import 'package:flutter/material.dart';

import '../../models/alcohol_test_result.dart';
import '../../models/history_filter.dart';
import '../../models/history_report.dart';
import '../../models/safety_status.dart';
import '../../models/test_type.dart';
import '../../services/demo_test_history_repository.dart';
import '../../services/report_service.dart';
import '../../services/test_history_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/dashboard_stat_card.dart';
import '../../widgets/history_charts.dart';
import '../../widgets/history_record_card.dart';
import '../../widgets/main_navigation_bar.dart';
import '../../widgets/primary_button.dart';
import 'history_detail_sheet.dart';
import 'report_preview_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/user_profile_repository.dart';
import '../../services/demo_user_profile_repository.dart';
import '../../services/app_session.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.repository,
    this.referenceDate,
    this.reportService = const ReportService(),
    this.profileRepository,
  });

  final TestHistoryRepository? repository;
  final DateTime? referenceDate;
  final ReportService reportService;
  final UserProfileRepository? profileRepository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  TestHistoryRepository get _repository =>
      widget.repository ??
      AppSession.maybeOf(context)?.history ??
      const DemoTestHistoryRepository();
  bool get _production => AppSession.maybeOf(context) != null;
  UserProfileRepository get _profiles =>
      widget.profileRepository ??
      AppSession.maybeOf(context)?.profiles ??
      DemoUserProfileRepository.session;
  List<AlcoholTestResult> _records = const [];
  bool _loading = true;
  bool _failed = false;
  bool _reporting = false;
  HistoryPeriod _period = HistoryPeriod.weekly;
  TestType? _type;
  DateTimeRange? _range;
  late DateTime _reference;
  SessionChanges? _changes;

  @override
  void initState() {
    super.initState();
    _changes = AppSession.maybeOf(context)?.changes;
    _changes?.addListener(_load);
    _reference =
        widget.referenceDate ??
        (_production
            ? DateTime.now()
            : DemoTestHistoryRepository.referenceDate);
    _load();
  }

  @override
  void dispose() {
    _changes?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await _repository.getResults();
      if (!mounted) return;
      setState(() {
        _records = List.unmodifiable(results);
        if (!_production &&
            widget.referenceDate == null &&
            results.isNotEmpty) {
          _reference = historyDay(
            results
                .map((r) => r.timestamp)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          );
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  HistoryFilter get _filter => HistoryFilter(
    period: _period,
    testType: _type,
    referenceDate: _reference,
    customStart: _range?.start,
    customEnd: _range?.end,
  );

  void _reset() => setState(() {
    _period = HistoryPeriod.weekly;
    _type = null;
    _range = null;
  });

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      currentDate: _reference,
      initialDateRange: _range,
      helpText: 'Select history dates',
    );
    if (mounted && range != null) setState(() => _range = range);
  }

  Future<void> _report() async {
    if (_reporting) return;
    final records = _records;
    final filter = _filter;
    setState(() => _reporting = true);
    try {
      final profile = _production ? await _profiles.getProfile() : null;
      final snapshot = HistoryReport(
        source: records,
        filter: filter,
        generatedAt: DateTime.now(),
        profile: profile,
        isDemo: !_production,
      );
      final bytes = await widget.reportService.generate(snapshot);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportPreviewScreen(bytes: bytes),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to generate the report. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('History')),
    bottomNavigationBar: MainNavigationBar(
      selected: MainDestination.history,
      onSelected: (destination) {
        if (destination == MainDestination.home) {
          Navigator.of(context).maybePop();
        }
        if (destination == MainDestination.settings) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(repository: _profiles),
            ),
          );
        }
        if (destination == MainDestination.notifications) {
          const label = 'Notifications';
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('$label will be implemented later.')),
            );
        }
      },
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load history.'),
                  TextButton(onPressed: _load, child: const Text('RETRY')),
                ],
              ),
            )
          : _content(context),
    ),
  );

  Widget _content(BuildContext context) {
    final filter = _filter;
    final report = HistoryReport(
      source: _records,
      filter: filter,
      generatedAt: DateTime.now(),
    );
    final analytics = report.analytics;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Review prototype alcohol sensor test records'),
              const SizedBox(height: 12),
              Text(
                _production ? 'SAVED SIMULATION RECORDS' : 'DEMO DATA',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text('DEMO HISTORY · Fixed samples, not real user tests.'),
              const SizedBox(height: 6),
              Text(
                'Period ending ${historyDate(_reference)}${_production ? '' : ' (latest demo date)'}.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final period in HistoryPeriod.values)
                    ChoiceChip(
                      label: Text(switch (period) {
                        HistoryPeriod.daily => 'Daily',
                        HistoryPeriod.weekly => 'Weekly',
                        HistoryPeriod.monthly => 'Monthly',
                      }),
                      selected: _period == period && _range == null,
                      onSelected: (_) => setState(() {
                        _period = period;
                        _range = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in <TestType?>[null, ...TestType.values])
                    ChoiceChip(
                      label: Text(type?.label ?? 'All'),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _pickDates,
                    icon: const Icon(Icons.date_range),
                    label: const Text('Select date range'),
                  ),
                  if (_range != null)
                    TextButton(
                      onPressed: () => setState(() => _range = null),
                      child: const Text('Clear date range'),
                    ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset filters'),
                  ),
                ],
              ),
              Text(
                '${filter.periodLabel} · ${filter.typeLabel}\n${filter.rangeLabel}',
                key: const ValueKey('active-history-filter'),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 650 ? 4 : 2;
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: DashboardStatCard(
                          label: 'TOTAL TESTS',
                          value: analytics.total,
                          icon: Icons.fact_check_outlined,
                          color: AppColors.gold,
                        ),
                      ),
                      for (final status in SafetyStatus.values)
                        SizedBox(
                          width: width,
                          child: DashboardStatCard(
                            label: status.name.toUpperCase(),
                            value: analytics.count(status),
                            icon: switch (status) {
                              SafetyStatus.safe => Icons.check_circle_outline,
                              SafetyStatus.caution =>
                                Icons.warning_amber_rounded,
                              SafetyStatus.danger => Icons.error_outline,
                            },
                            color: historyStatusColor(status),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Analytics', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Prototype Sensor Reading: ${analytics.averageReading.toStringAsFixed(3)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Highest Prototype Sensor Reading: ${analytics.highestReading.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 16),
                    Text('Vehicle Tests: ${analytics.vehicleCount}'),
                    Text('Office Tests: ${analytics.officeCount}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HistoryTrendChart(
                points: analytics.trend,
                title: filter.isCustom
                    ? 'Alcohol Detection Trend'
                    : switch (_period) {
                        HistoryPeriod.daily => 'Daily Alcohol Detection Trend',
                        HistoryPeriod.weekly =>
                          'Weekly Alcohol Detection Trend',
                        HistoryPeriod.monthly =>
                          'Monthly Alcohol Detection Trend',
                      },
              ),
              const SizedBox(height: 16),
              HistoryStatusChart(analytics: analytics),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'GENERATE REPORT',
                icon: Icons.picture_as_pdf_outlined,
                isLoading: _reporting,
                onPressed: _report,
              ),
              const SizedBox(height: 24),
              Text(
                'Test records',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (report.records.isEmpty)
                CustomCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.history,
                        color: AppColors.secondaryText,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _production && _records.isEmpty
                            ? 'No saved test records yet.'
                            : 'No test records found for this period.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _reset,
                        child: const Text('CLEAR FILTERS'),
                      ),
                    ],
                  ),
                )
              else
                for (final record in report.records)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: HistoryRecordCard(
                      record: record,
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => HistoryDetailSheet(record: record),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
