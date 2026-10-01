import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';
import '../models/sms_send_result.dart';
import '../services/emergency_sms_service.dart';
import '../services/user_profile_repository.dart';
import '../screens/settings/emergency_contact_screen.dart';
import 'primary_button.dart';

class EmergencyAlertSection extends StatefulWidget {
  const EmergencyAlertSection({
    super.key,
    required this.profileRepository,
    required this.smsService,
  });
  final UserProfileRepository profileRepository;
  final EmergencySmsService smsService;
  static const alertMessage =
      'SafeStart Alert: A high prototype alcohol sensor reading was detected during a Vehicle Safety Test. Please check on the user.';
  @override
  State<EmergencyAlertSection> createState() => _EmergencyAlertSectionState();
}

class _EmergencyAlertSectionState extends State<EmergencyAlertSection> {
  EmergencyContact? _contact;
  bool _loading = true, _loadFailed = false, _confirming = false;
  SmsSendResult _result = const SmsSendResult(SmsStatus.idle);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final profile = await widget.profileRepository.getProfile();
      if (!mounted) return;
      setState(() {
        _contact = profile.emergencyContact;
        _result = SmsSendResult(
          _contact == null ? SmsStatus.noEmergencyContact : SmsStatus.idle,
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _configure() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EmergencyContactScreen(repository: widget.profileRepository),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _send() async {
    if (_confirming ||
        _result.status == SmsStatus.sending ||
        _result.status == SmsStatus.sent ||
        _contact == null) {
      return;
    }
    setState(() => _confirming = true);
    final contact = _contact!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send emergency alert?'),
        scrollable: true,
        content: Text(
          "This will send an SMS to ${contact.name} at ${contact.phoneNumber} using this phone's SIM.\n\nThe sensor result is simulated. Sending SMS is real and carrier charges may apply.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('SEND SMS'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (confirmed == true) _result = const SmsSendResult(SmsStatus.sending);
    });
    if (confirmed != true) return;
    try {
      final result = await widget.smsService.sendEmergencyAlert(
        phoneNumber: contact.phoneNumber,
        message: EmergencyAlertSection.alertMessage,
      );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(() => _result = const SmsSendResult(SmsStatus.failed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _result.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Emergency Contact Alert',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_loadFailed) ...[
          const Text('Unable to load emergency contact.'),
          TextButton(
            onPressed: _load,
            child: const Text('RETRY CONTACT LOOKUP'),
          ),
        ] else if (_contact == null) ...[
          const Text('No emergency contact configured.'),
          TextButton(
            onPressed: _configure,
            child: const Text('SET EMERGENCY CONTACT'),
          ),
        ] else ...[
          Text(_contact!.name),
          Text(_contact!.phoneNumber),
          const SizedBox(height: 12),
          Text(switch (status) {
            SmsStatus.sending => 'Sending emergency alert...',
            SmsStatus.sent => 'Emergency alert sent',
            SmsStatus.failed => 'Emergency alert could not be sent.',
            SmsStatus.permissionDenied =>
              'SMS permission is required to send the emergency alert.',
            SmsStatus.unsupported => 'SMS is not supported on this device.',
            _ => 'No SMS sent. Confirmation is required.',
          }),
          if (status == SmsStatus.sent) ...[
            Text('SMS sent to ${_contact!.name}.'),
            const Text('This confirms sending, not delivery to the recipient.'),
          ],
          if (_result.message != null) Text(_result.message!),
          if (_result.permanentlyDenied)
            const Text(
              'Open Android Settings > Apps > SafeStart > Permissions and allow SMS. Then return to this result and try again.',
            ),
          const SizedBox(height: 16),
          if (status != SmsStatus.sent &&
              status != SmsStatus.unsupported &&
              _result.canRetry)
            PrimaryButton(
              label: status == SmsStatus.idle
                  ? 'SEND EMERGENCY ALERT'
                  : 'TRY AGAIN',
              isLoading: status == SmsStatus.sending,
              onPressed: _confirming || status == SmsStatus.sending
                  ? null
                  : _send,
            ),
        ],
      ],
    );
  }
}
