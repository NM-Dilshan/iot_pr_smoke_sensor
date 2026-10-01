import '../models/safety_status.dart';

class AlcoholClassificationService {
  const AlcoholClassificationService();

  // Demo sensor thresholds only, not legal, medical, or calibrated BAC limits.
  // Replace or adjust after real MQ-3 calibration and project evaluation.
  static const cautionThreshold = 0.20;
  static const dangerThreshold = 0.40;

  SafetyStatus classify(double reading) {
    if (!reading.isFinite || reading < 0) {
      throw ArgumentError.value(
        reading,
        'reading',
        'Must be finite and nonnegative',
      );
    }
    if (reading < cautionThreshold) return SafetyStatus.safe;
    if (reading < dangerThreshold) return SafetyStatus.caution;
    return SafetyStatus.danger;
  }
}
