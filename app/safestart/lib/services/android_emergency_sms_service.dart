import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/sms_send_result.dart';
import 'emergency_sms_service.dart';

class AndroidEmergencySmsService implements EmergencySmsService {
  const AndroidEmergencySmsService();
  static const _channel = MethodChannel('safestart/emergency_sms');

  @override
  Future<SmsSendResult> sendEmergencyAlert({
    required String phoneNumber,
    required String message,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SmsSendResult(
        SmsStatus.unsupported,
        message: 'Direct SMS requires a supported Android phone with a SIM.',
        canRetry: false,
      );
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'sendEmergencyAlert',
        {'phoneNumber': phoneNumber, 'message': message},
      );
      final status = switch (data?['status']) {
        'sent' => SmsStatus.sent,
        'permissionDenied' => SmsStatus.permissionDenied,
        'unsupported' => SmsStatus.unsupported,
        _ => SmsStatus.failed,
      };
      return SmsSendResult(
        status,
        message: data?['message'] as String?,
        permanentlyDenied: data?['permanentlyDenied'] == true,
        canRetry: data?['canRetry'] != false,
      );
    } on MissingPluginException {
      return const SmsSendResult(
        SmsStatus.unsupported,
        message: 'SMS is unavailable on this platform.',
        canRetry: false,
      );
    } on PlatformException {
      return const SmsSendResult(
        SmsStatus.failed,
        message: 'Android could not complete the SMS request.',
      );
    }
  }
}
