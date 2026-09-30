import 'package:flutter/material.dart';

import '../../models/test_type.dart';
import '../test/test_preparation_screen.dart';
import '../test/test_selection_screen.dart';

import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/dashboard_stat_card.dart';
import '../../widgets/main_navigation_bar.dart';
import '../../widgets/test_option_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MainNavigationBar(
      selected: MainDestination.home,
      onSelected: (destination) {
        final message = switch (destination) {
          MainDestination.home => null,
          MainDestination.history => 'History will be implemented later.',
          MainDestination.notifications =>
            'Notifications will be implemented later.',
          MainDestination.settings => 'Settings will be implemented later.',
        };
        if (message != null) _message(context, message);
      },
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/safestart_logo.png',
                        width: 44,
                        height: 46,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SafeStart',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => _message(
                        context,
                        'Notifications will be available in a later step.',
                      ),
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Welcome back'),
                const SizedBox(height: 4),
                Text(
                  'Alex',
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text('Stay safe. Stay responsible.'),
                const SizedBox(height: 24),
                CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SYSTEM STATUS',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ready for Safety Test',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      const Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          _StatusDetail(
                            icon: Icons.science_outlined,
                            label: 'Device Status',
                            value: 'Demo Mode',
                          ),
                          _StatusDetail(
                            icon: Icons.wifi_off_rounded,
                            label: 'Connection',
                            value: 'Not Connected',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Start Safety Test'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TestSelectionScreen(),
                      ),
                    ),
                    child: const Text('Choose test type'),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 650
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: TestOptionCard(
                            title: 'Vehicle Test',
                            description: 'Check alcohol level before driving.',
                            assetPath: 'assets/images/vehicle_test.png',
                            actionLabel: 'START VEHICLE TEST',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const TestPreparationScreen(
                                  testType: TestType.vehicle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TestOptionCard(
                            title: 'Office Test',
                            description: 'Perform workplace alcohol screening.',
                            assetPath: 'assets/images/office_test.png',
                            actionLabel: 'START OFFICE TEST',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const TestPreparationScreen(
                                  testType: TestType.office,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Safety Overview'),
                const Text(
                  'DEMO / SAMPLE VALUES',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 650 ? 4 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final stat in const [
                          (
                            'Tests Today',
                            Icons.fact_check_outlined,
                            AppColors.gold,
                          ),
                          ('Safe', Icons.check_circle_outline, AppColors.safe),
                          (
                            'Caution',
                            Icons.warning_amber_rounded,
                            AppColors.caution,
                          ),
                          ('Danger', Icons.error_outline, AppColors.danger),
                        ])
                          SizedBox(
                            width: width,
                            child: DashboardStatCard(
                              label: stat.$1,
                              value: 0,
                              icon: stat.$2,
                              color: stat.$3,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Recent Activity'),
                CustomCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.history,
                        color: AppColors.secondaryText,
                        size: 32,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No tests recorded yet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your recent safety tests will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Quick Actions'),
                CustomCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.history,
                          color: AppColors.gold,
                        ),
                        title: const Text('History'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _message(
                          context,
                          'History will be implemented in a later step.',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.contact_phone_outlined,
                          color: AppColors.gold,
                        ),
                        title: const Text('Emergency Contact'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _message(
                          context,
                          'Emergency Contact will be implemented in a later step.',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.wifi_off_rounded,
                          color: AppColors.gold,
                        ),
                        title: const Text('Device Status'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _message(
                          context,
                          'ESP32 device is not connected. SafeStart is currently in Demo Mode.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _StatusDetail extends StatelessWidget {
  const _StatusDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppColors.gold, size: 24),
      const SizedBox(width: 12),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    ],
  );
}
