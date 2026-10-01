import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/user_profile_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/profile_page.dart';
import '../settings/emergency_contact_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.repository});
  final UserProfileRepository repository;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  @override
  Widget build(BuildContext context) => ProfilePage(
    title: 'Profile',
    child: FutureBuilder<UserProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('Unable to load profile.'),
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
            const Center(
              child: CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.surface,
                child: Icon(
                  Icons.person_outline,
                  size: 42,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text('Employee ID: ${profile.employeeId}'),
                  Text('Email: ${profile.email}'),
                  Text('User Type: ${profile.userType.label}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'EDIT PROFILE',
              onPressed: () => _open(
                EditProfileScreen(
                  repository: widget.repository,
                  profile: profile,
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contact',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    contact == null
                        ? 'Not configured'
                        : '${contact.name}\n${contact.phoneNumber}\n${contact.relationship.label}',
                  ),
                  TextButton(
                    onPressed: () => _open(
                      EmergencyContactScreen(repository: widget.repository),
                    ),
                    child: Text(
                      contact == null ? 'ADD CONTACT' : 'EDIT CONTACT',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
