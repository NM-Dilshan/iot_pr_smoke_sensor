import 'package:flutter/material.dart';

import '../../services/app_session.dart';

import '../../models/user_profile.dart';
import '../../services/user_profile_repository.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/profile_page.dart';
import '../auth/auth_validators.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.repository,
    required this.profile,
  });
  final UserProfileRepository repository;
  final UserProfile profile;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _id;
  late final TextEditingController _email;
  late UserType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _id = TextEditingController(text: widget.profile.employeeId);
    _email = TextEditingController(text: widget.profile.email);
    _type = widget.profile.userType;
  }

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final name = _name.text.trim(),
        id = _id.text.trim(),
        email = _email.text.trim();
    final type = _type;
    setState(() => _saving = true);
    try {
      final current = await widget.repository.getProfile();
      await widget.repository.updateProfile(
        current.copyWith(
          fullName: name,
          employeeId: id,
          email: email,
          userType: type,
        ),
      );
      if (!mounted) return;
      AppSession.maybeOf(context)?.changes.refresh();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPersistent
                ? 'Profile saved.'
                : 'Profile updated for this session.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save profile. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfilePage(
    title: 'Edit Profile',
    child: Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full Name'),
            validator: (value) =>
                AuthValidators.requiredField(value, 'full name'),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _id,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Employee ID'),
            validator: (value) =>
                AuthValidators.requiredField(value, 'employee ID'),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _email,
            readOnly: !widget.repository.emailEditable,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Email',
              helperText: widget.repository.emailEditable
                  ? null
                  : 'Account email is read-only.',
            ),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<UserType>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'User Type'),
            items: [
              for (final type in UserType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _type = value!),
            validator: (value) => value == null ? 'Select a user type.' : null,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'SAVE CHANGES',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    ),
  );
}
