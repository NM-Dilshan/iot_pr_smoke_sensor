import 'package:flutter/foundation.dart';

import '../models/emergency_contact.dart';
import '../models/sms_send_result.dart';
import 'emergency_sms_service.dart';
import 'profile_validators.dart';
import 'user_profile_repository.dart';

/// Created only by the active test flow after an explicitly started device
/// Vehicle test completes as DANGER. Never restored from saved records.
class VehicleEmergencyAlert extends ChangeNotifier {
  VehicleEmergencyAlert({required this.profiles, required this.sms});
  final UserProfileRepository profiles;
  final EmergencySmsService sms;
  static const message =
      'SafeStart Alert: A high alcohol-vapor sensor reading was detected during a Vehicle Test. Please check on the user.';
  bool _attempted = false;
  EmergencyContact? contact;
  SmsSendResult result = const SmsSendResult(SmsStatus.idle);

  Future<void> sendOnce() async {
    if (_attempted) return;
    // Claim before profile loading or permission requests, including failures.
    _attempted = true;
    result = const SmsSendResult(SmsStatus.sending);
    notifyListeners();
    try {
      contact = (await profiles.getProfile()).emergencyContact;
      if (contact == null) {
        result = const SmsSendResult(SmsStatus.noEmergencyContact);
      } else if (ProfileValidators.phone(contact!.phoneNumber) != null) {
        result = const SmsSendResult(
          SmsStatus.failed,
          message: 'Check the emergency contact phone number in Settings.',
        );
      } else {
        result = await sms.sendEmergencyAlert(
          phoneNumber: contact!.phoneNumber,
          message: message,
        );
      }
    } catch (_) {
      result = const SmsSendResult(
        SmsStatus.failed,
        message: 'Unable to load the emergency contact or send the alert.',
      );
    }
    notifyListeners();
  }
}
