import 'safety_status.dart';
import 'test_type.dart';

class AlcoholTestResult {
  const AlcoholTestResult({
    required this.testType,
    required this.sensorReading,
    required this.status,
    required this.timestamp,
  });

  final TestType testType;
  final double sensorReading;
  final SafetyStatus status;
  final DateTime timestamp;
}
