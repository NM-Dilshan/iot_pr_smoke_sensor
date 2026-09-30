import 'alcohol_sensor_service.dart';

enum MockSensorScenario { low, medium, high }

/// Deterministic, unitless prototype values; these are not calibrated readings.
class MockAlcoholSensorService implements AlcoholSensorService {
  const MockAlcoholSensorService({this.simulatedReading = 0.18});

  factory MockAlcoholSensorService.scenario(MockSensorScenario scenario) =>
      MockAlcoholSensorService(
        simulatedReading: switch (scenario) {
          MockSensorScenario.low => 0.02,
          MockSensorScenario.medium => 0.18,
          MockSensorScenario.high => 0.35,
        },
      );

  final double simulatedReading;

  @override
  Future<double> readAlcoholLevel() async => simulatedReading;
}
