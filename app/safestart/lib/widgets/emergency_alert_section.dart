import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';
import '../models/sms_send_result.dart';
import '../services/emergency_sms_service.dart';
import '../services/user_profile_repository.dart';
import '../screens/settings/emergency_contact_screen.dart';
import '../services/vehicle_emergency_alert.dart';

class EmergencyAlertSection extends StatefulWidget {
  const EmergencyAlertSection({
    super.key,
    required this.profileRepository,
    required this.smsService,
    this.automaticAlert,
  });
  final UserProfileRepository profileRepository;
  final EmergencySmsService smsService;
  final VehicleEmergencyAlert? automaticAlert;
  static const alertMessage = VehicleEmergencyAlert.message;
  @override
  State<EmergencyAlertSection> createState() => _EmergencyAlertSectionState();
}

class _EmergencyAlertSectionState extends State<EmergencyAlertSection> {
  EmergencyContact? _contact;
  bool _loading = true, _loadFailed = false;
  SmsSendResult _result = const SmsSendResult(SmsStatus.idle);
  @override
  void initState() {
    super.initState();
    if (widget.automaticAlert == null) _load();
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

  @override
  Widget build(BuildContext context) {
    final alert = widget.automaticAlert;
    if (alert != null) {
      return AnimatedBuilder(
        animation: alert,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contact Alert',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (alert.contact != null) ...[
              Text(alert.contact!.name),
              Text(alert.contact!.phoneNumber),
            ],
            Text(switch (alert.result.status) {
              SmsStatus.sending => 'Sending emergency alert...',
              SmsStatus.sent => 'Emergency alert sent',
              SmsStatus.noEmergencyContact =>
                'No emergency contact configured.',
              SmsStatus.permissionDenied =>
                'SMS permission is required to send the emergency alert.',
              SmsStatus.unsupported => 'SMS is not supported on this device.',
              SmsStatus.failed => 'Emergency alert could not be sent.',
              SmsStatus.idle => 'Emergency alert pending.',
            }),
            if (alert.result.message != null) Text(alert.result.message!),
            if (alert.result.permanentlyDenied)
              const Text(
                'Open Android Settings > Apps > SafeStart > Permissions and allow SMS for future tests.',
              ),
            if (alert.result.status == SmsStatus.sent)
              const Text(
                'This confirms sending, not delivery to the recipient.',
              ),
          ],
        ),
      );
    }
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
            _ => 'Automatic alerts apply only to a newly completed Vehicle device test.',
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
        ],
      ],
    );
  }
}
