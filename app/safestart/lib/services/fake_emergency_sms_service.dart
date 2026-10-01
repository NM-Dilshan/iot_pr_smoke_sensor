import '../models/sms_send_result.dart';
import 'emergency_sms_service.dart';

/// Test-only substitute: never accesses a platform channel or sends a message.
class FakeEmergencySmsService implements EmergencySmsService {
  FakeEmergencySmsService({
    this.result = const SmsSendResult(SmsStatus.sent),
    this.response,
  });
  SmsSendResult result;
  Future<SmsSendResult>? response;
  int calls = 0;
  String? lastPhoneNumber;
  String? lastMessage;

  @override
  Future<SmsSendResult> sendEmergencyAlert({
    required String phoneNumber,
    required String message,
  }) async {
    calls++;
    lastPhoneNumber = phoneNumber;
    lastMessage = message;
    return response == null ? result : await response!;
  }
}
