enum SmsStatus {
  idle,
  sending,
  sent,
  failed,
  permissionDenied,
  noEmergencyContact,
  unsupported,
}

class SmsSendResult {
  const SmsSendResult(
    this.status, {
    this.message,
    this.permanentlyDenied = false,
    this.canRetry = true,
  });
  final SmsStatus status;
  final String? message;
  final bool permanentlyDenied;
  final bool canRetry;
}
