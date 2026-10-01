import 'package:flutter/material.dart';

import '../../models/emergency_contact.dart';
import '../../services/user_profile_repository.dart';
import '../../services/profile_validators.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/profile_page.dart';
import '../auth/auth_validators.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key, required this.repository});
  final UserProfileRepository repository;
  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  ContactRelationship? _relationship;
  bool _loading = true, _failed = false, _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final contact = (await widget.repository.getProfile()).emergencyContact;
      if (!mounted) return;
      _name.text = contact?.name ?? '';
      _phone.text = contact?.phoneNumber ?? '';
      setState(() {
        _relationship = contact?.relationship;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final contact = EmergencyContact(
      name: _name.text.trim(),
      phoneNumber: _phone.text.trim(),
      relationship: _relationship!,
    );
    setState(() => _saving = true);
    try {
      final profile = await widget.repository.getProfile();
      await widget.repository.updateProfile(
        profile.copyWith(emergencyContact: contact),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPersistent
                ? 'Emergency contact saved. No SMS sent.'
                : 'Emergency contact saved for this session. No SMS sent.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save contact. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfilePage(
    title: 'Emergency Contact',
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? Column(
            children: [
              const Text('Unable to load contact.'),
              TextButton(onPressed: _load, child: const Text('RETRY')),
            ],
          )
        : Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SMS permission will be requested when an alert is sent.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Contact Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      AuthValidators.requiredField(value, 'contact name'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: ProfileValidators.phone,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<ContactRelationship>(
                  initialValue: _relationship,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: [
                    for (final relationship in ContactRelationship.values)
                      DropdownMenuItem(
                        value: relationship,
                        child: Text(relationship.label),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _relationship = value),
                  validator: (value) =>
                      value == null ? 'Select a relationship.' : null,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'SAVE EMERGENCY CONTACT',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
  );
}
