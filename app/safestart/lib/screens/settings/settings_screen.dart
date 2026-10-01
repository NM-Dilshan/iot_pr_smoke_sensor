import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/user_profile_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/main_navigation_bar.dart';
import '../../widgets/profile_page.dart';
import '../auth/login_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import 'emergency_contact_screen.dart';
import '../../services/app_session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});
  final UserProfileRepository repository;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<UserProfile> _profile;
  @override
  void initState() {
    super.initState();
    _profile = widget.repository.getProfile();
  }

  void _reload() => setState(() {
    _profile = widget.repository.getProfile();
  });
  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _reload();
  }

  void _info(String title, String text) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(text),
      scrollable: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out of SafeStart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final session = AppSession.maybeOf(context);
    if (session != null) {
      try {
        await session.auth.signOut();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to sign out. Please try again.'),
            ),
          );
        }
      }
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        CustomCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ProfilePage(
    title: 'Settings',
    bottomNavigationBar: MainNavigationBar(
      selected: MainDestination.settings,
      onSelected: (destination) {
        switch (destination) {
          case MainDestination.home:
            Navigator.of(context).popUntil((route) => route.isFirst);
          case MainDestination.history:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) =>
                    HistoryScreen(profileRepository: widget.repository),
              ),
            );
          case MainDestination.notifications:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Notifications will be implemented later.'),
                ),
              );
          case MainDestination.settings:
            break;
        }
      },
    ),
    child: FutureBuilder<UserProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('Unable to load settings.'),
              TextButton(onPressed: _reload, child: const Text('RETRY')),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data!;
        final contact = profile.emergencyContact;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('ACCOUNT', [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                subtitle: Text(profile.fullName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _open(ProfileScreen(repository: widget.repository)),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('User Type'),
                subtitle: Text(profile.userType.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _open(ProfileScreen(repository: widget.repository)),
              ),
            ]),
            _section('SAFETY', [
              ListTile(
                leading: const Icon(Icons.contact_phone_outlined),
                title: const Text('Emergency Contact'),
                subtitle: Text(
                  contact == null
                      ? 'Not configured'
                      : '${contact.name}\n${contact.phoneNumber}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  EmergencyContactScreen(repository: widget.repository),
                ),
              ),
              if (contact != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _open(
                      EmergencyContactScreen(repository: widget.repository),
                    ),
                    child: const Text('EDIT CONTACT'),
                  ),
                ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.notifications_off_outlined),
                title: Text('Emergency Alerts'),
                subtitle: Text(
                  'SMS permission will be requested when an alert is sent.',
                ),
              ),
            ]),
            _section('DEVICE', const [
              ListTile(
                leading: Icon(Icons.wifi_off),
                title: Text('Device Connection'),
                subtitle: Text('Not Connected'),
              ),
              ListTile(title: Text('Mode'), subtitle: Text('Demo Mode')),
              ListTile(
                title: Text('Future Device: ESP32 + MQ-3'),
                subtitle: Text('Hardware integration will be added later.'),
              ),
            ]),
            _section('APP', [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About SafeStart'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _info(
                  'SafeStart',
                  'SafeStart is a university IoT prototype designed to explore alcohol-sensor-based safety screening for vehicle and workplace scenarios.\n\nSafeStart is not a certified breathalyzer, medical device, or legal BAC measurement system.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help / Instructions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _info(
                  'Help / Instructions',
                  '1. Select Vehicle or Office test.\n\n2. Read preparation instructions.\n\n3. Start the prototype sensor test.\n\n4. Follow the on-screen breath instructions.\n\n5. Review the prototype safety classification.\n\n6. Use History to review prototype records and reports.\n\nCurrent tests use simulated data. Hardware is not connected.',
                ),
              ),
            ]),
            _section('ACCOUNT / SYSTEM', [
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.gold),
                title: const Text('LOG OUT'),
                onTap: _logout,
              ),
            ]),
          ],
        );
      },
    ),
  );
}
