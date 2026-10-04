import 'package:flutter/material.dart';

import '../models/alcohol_test_result.dart';
import '../models/user_profile.dart';
import '../models/safety_status.dart';
import '../screens/history/history_detail_sheet.dart';
import '../models/history_filter.dart';
import '../services/app_session.dart';
import '../services/user_profile_repository.dart';
import '../services/history_analytics_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_stat_card.dart';
import 'history_record_card.dart';

class StoredProfileName extends StatefulWidget {
  const StoredProfileName({super.key, required this.repository});
  final UserProfileRepository repository;
  @override
  State<StoredProfileName> createState() => _StoredProfileNameState();
}

class _StoredProfileNameState extends State<StoredProfileName> {
  late Future<UserProfile> _profile;
  SessionChanges? _changes;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_changes == null) {
      _changes = AppSession.maybeOf(context)?.changes;
      _changes?.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _profile = widget.repository.getProfile();
      });
    }
  }

  @override
  void dispose() {
    _changes?.removeListener(_refresh);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.getProfile();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserProfile>(
    future: _profile,
    builder: (context, snapshot) => snapshot.hasError
        ? TextButton(
            onPressed: () => setState(() {
              _profile = widget.repository.getProfile();
            }),
            child: const Text('RETRY PROFILE'),
          )
        : Text(
            snapshot.data?.fullName ?? 'Loading profile...',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
  );
}

class StoredDashboard extends StatefulWidget {
  const StoredDashboard({super.key, required this.session});
  final AppSession session;
  @override
  State<StoredDashboard> createState() => _StoredDashboardState();
}

class _StoredDashboardState extends State<StoredDashboard> {
  late Future<List<AlcoholTestResult>> _records;
  @override
  void initState() {
    super.initState();
    _records = widget.session.history.getResults();
    widget.session.changes.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _records = widget.session.history.getResults();
      });
    }
  }

  @override
  void dispose() {
    widget.session.changes.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AlcoholTestResult>>(
    future: _records,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text('Unable to load saved statistics.'),
            TextButton(
              onPressed: _refresh,
              child: const Text('RETRY STATISTICS'),
            ),
          ],
        );
      }
      final records = snapshot.data!;
      final today = records
          .where((r) => historyDay(r.timestamp) == historyDay(DateTime.now()))
          .toList();
      final stats = const HistoryAnalyticsService().calculate(today);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Safety Overview · Today',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('Saved prototype sensor records'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in [
                  ('Tests Today', stats.total, AppColors.gold),
                  ('Safe', stats.count(SafetyStatus.safe), AppColors.safe),
                  (
                    'Caution',
                    stats.count(SafetyStatus.caution),
                    AppColors.caution,
                  ),
                  (
                    'Danger',
                    stats.count(SafetyStatus.danger),
                    AppColors.danger,
                  ),
                ])
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: DashboardStatCard(
                      label: entry.$1,
                      value: entry.$2,
                      icon: Icons.assessment_outlined,
                      color: entry.$3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (records.isEmpty)
            const Text('No saved test records yet.')
          else
            for (final record in records.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: HistoryRecordCard(
                  record: record,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => HistoryDetailSheet(record: record),
                  ),
                ),
              ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}
