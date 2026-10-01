import '../models/sms_send_result.dart';

abstract class EmergencySmsService {
  Future<SmsSendResult> sendEmergencyAlert({
    required String phoneNumber,
    required String message,
  });
}
