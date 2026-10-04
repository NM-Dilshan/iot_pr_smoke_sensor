import 'safety_status.dart';
import 'test_type.dart';

class AlcoholTestResult {
  const AlcoholTestResult({
    required this.testType,
    required this.sensorReading,
    required this.status,
    required this.timestamp,
    this.isEsp32Vehicle = false,
    this.isEsp32Office = false,
  });

  final bool isEsp32Vehicle;
  final bool isEsp32Office;
  bool get isEsp32Hardware => isEsp32Vehicle || isEsp32Office;
  final TestType testType;
  final double sensorReading;
  final SafetyStatus status;
  final DateTime timestamp;
}
