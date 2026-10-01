import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/app_session.dart';
import '../../services/user_profile_repository.dart';
import '../../services/test_history_repository.dart';
import '../../services/firestore_user_profile_repository.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'auth_validators.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({
    super.key,
    required this.auth,
    required this.profiles,
    required this.history,
  });
  final AuthService auth;
  final UserProfileRepository Function(String uid) profiles;
  final TestHistoryRepository Function(String uid) history;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) {
      final uid = auth.uid;
      return uid == null
          ? MaterialApp(
              key: const ValueKey('signed-out'),
              theme: AppTheme.dark,
              debugShowCheckedModeBanner: false,
              home: LoginScreen(auth: auth, managedSession: true),
            )
          : _SignedIn(
              key: ValueKey(uid),
              auth: auth,
              profiles: profiles(uid),
              history: history(uid),
            );
    },
  );
}

class _SignedIn extends StatefulWidget {
  const _SignedIn({
    super.key,
    required this.auth,
    required this.profiles,
    required this.history,
  });
  final AuthService auth;
  final UserProfileRepository profiles;
  final TestHistoryRepository history;
  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  late Future<UserProfile> _profile;
  final _changes = SessionChanges();
  @override
  void initState() {
    super.initState();
    _profile = widget.profiles.getProfile();
  }

  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  void _retry() => setState(() {
    _profile = widget.profiles.getProfile();
  });
  @override
  Widget build(BuildContext context) => AppSession(
    auth: widget.auth,
    profiles: widget.profiles,
    history: widget.history,
    changes: _changes,
    child: MaterialApp(
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<UserProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return HomeScreen(profileRepository: widget.profiles);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Account setup')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (snapshot.error is MissingProfile &&
                      widget.profiles is FirestoreUserProfileRepository)
                    _CompleteProfile(
                      repository:
                          widget.profiles as FirestoreUserProfileRepository,
                      onSaved: _retry,
                    )
                  else ...[
                    const Text(
                      'Unable to load your profile. Check your connection and try again.',
                    ),
                    TextButton(onPressed: _retry, child: const Text('RETRY')),
                  ],
                  TextButton(
                    onPressed: () async {
                      try {
                        await widget.auth.signOut();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to sign out. Try again.'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('LOG OUT'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _CompleteProfile extends StatefulWidget {
  const _CompleteProfile({required this.repository, required this.onSaved});
  final FirestoreUserProfileRepository repository;
  final VoidCallback onSaved;
  @override
  State<_CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends State<_CompleteProfile> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _employee = TextEditingController();
  UserType _type = UserType.employee;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _employee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createProfile(
        UserProfile(
          fullName: _name.text.trim(),
          employeeId: _employee.text.trim(),
          email: widget.repository.authEmail,
          userType: _type,
        ),
      );
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to save profile. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        const Text('Your account exists. Complete your profile to continue.'),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full Name'),
          validator: (v) => AuthValidators.requiredField(v, 'full name'),
        ),
        TextFormField(
          controller: _employee,
          decoration: const InputDecoration(labelText: 'Employee ID'),
          validator: (v) => AuthValidators.requiredField(v, 'employee ID'),
        ),
        DropdownButtonFormField<UserType>(
          initialValue: _type,
          items: UserType.values
              .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
              .toList(),
          onChanged: (v) => _type = v!,
        ),
        if (_error != null) Text(_error!),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'COMPLETE PROFILE'),
        ),
      ],
    ),
  );
}
