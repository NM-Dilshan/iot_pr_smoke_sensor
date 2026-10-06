import '../models/alcohol_test_result.dart';
import '../models/safety_status.dart';
import '../models/test_type.dart';
import 'alcohol_sensor_service.dart';
import 'esp32_service.dart';

class Esp32AlcoholSensorService implements AlcoholSensorService {
  Esp32AlcoholSensorService({
    required this.testType,
    Esp32Service? esp32Service,
  }) : _esp32Service = esp32Service ?? Esp32Service();

  final TestType testType;
  final Esp32Service _esp32Service;

  Future<void> startVehicleTest() => _esp32Service.startVehicleTest();

  Future<AlcoholTestResult?> pollVehicleResult() async {
    final status = await _esp32Service.getStatus();
    if (status.vehicleTestState != 'COMPLETED') return null;
    final safety = switch (status.vehicleTestResult) {
      'SAFE' => SafetyStatus.safe,
      'CAUTION' => SafetyStatus.caution,
      'DANGER' => SafetyStatus.danger,
      _ => throw const Esp32Exception('Invalid completed Vehicle result.'),
    };
    return AlcoholTestResult(
      testType: TestType.vehicle,
      sensorReading: status.vehicleResultReading.toDouble(),
      status: safety,
      timestamp: DateTime.now(),
      isEsp32Vehicle: true,
    );
  }

  String? lastOfficeGate;

  Future<String> readOfficeGate() async {
    final status = await _esp32Service.getStatus();
    return _validatedGate(status.gate);
  }

  String _validatedGate(String gate) {
    if (gate != 'OPEN' && gate != 'CLOSED') {
      throw const Esp32Exception(
        'Invalid gate state from the SafeStart device.',
      );
    }
    return gate;
  }

  Future<void> startOfficeTest() => _esp32Service.startOfficeTest();

  Future<AlcoholTestResult?> pollOfficeResult() async {
    final status = await _esp32Service.getStatus();
    final state = status.officeTestState;
    final result = status.officeTestResult;
    String? invalid;
    if (!['IDLE', 'COUNTDOWN', 'SAMPLING', 'COMPLETED'].contains(state)) {
      invalid = 'officeTestState: $state';
    } else if (state == 'COMPLETED') {
      if (!['SAFE', 'CAUTION', 'DANGER'].contains(result)) {
        invalid = 'officeTestResult for COMPLETED: $result';
      } else if (status.officeTestActive) {
        invalid = 'officeTestActive: true for COMPLETED';
      }
    } else if (![
      'NOT_TESTED',
      'PENDING',
      'SAFE',
      'CAUTION',
      'DANGER',
    ].contains(result)) {
      invalid = 'officeTestResult for $state: $result';
    }
    if (invalid != null) {
      throw Esp32Exception(
        'Invalid Office test status from the SafeStart device.',
        diagnostic: 'GET /status: invalid $invalid',
      );
    }
    lastOfficeGate = _validatedGate(status.gate);
    if (state != 'COMPLETED') return null;
    final safety = switch (result) {
      'SAFE' => SafetyStatus.safe,
      'CAUTION' => SafetyStatus.caution,
      'DANGER' => SafetyStatus.danger,
      _ => throw StateError('Unreachable validated result'),
    };
    return AlcoholTestResult(
      testType: TestType.office,
      sensorReading: status.officeResultReading.toDouble(),
      status: safety,
      timestamp: DateTime.now(),
      isEsp32Office: true,
    );
  }

  @override
  Future<double> readAlcoholLevel() async {
    if (testType == TestType.vehicle) {
      throw StateError(
        'Vehicle tests require an explicit start and completed result.',
      );
    }
    throw StateError(
      'Office tests require an explicit start and completed result.',
    );
  }
}
