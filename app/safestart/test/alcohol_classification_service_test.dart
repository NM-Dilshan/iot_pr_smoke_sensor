import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/services/alcohol_classification_service.dart';

void main() {
  const service = AlcoholClassificationService();
  final cases = {
    0.00: SafetyStatus.safe,
    0.10: SafetyStatus.safe,
    0.18: SafetyStatus.safe,
    0.19: SafetyStatus.safe,
    0.20: SafetyStatus.caution,
    0.30: SafetyStatus.caution,
    0.39: SafetyStatus.caution,
    0.40: SafetyStatus.danger,
    0.50: SafetyStatus.danger,
  };
  for (final entry in cases.entries) {
    test('Classifies ${entry.key} as ${entry.value.name}', () {
      expect(service.classify(entry.key), entry.value);
    });
  }
  test('Rejects invalid readings', () {
    for (final value in [
      -0.1,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => service.classify(value), throwsArgumentError);
    }
  });
}
