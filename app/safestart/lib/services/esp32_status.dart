class Esp32Exception implements Exception {
  const Esp32Exception(this.message, {this.diagnostic});
  final String message;
  final String? diagnostic;
  @override
  String toString() => diagnostic == null ? message : '$message ($diagnostic)';
}

class Esp32Status {
  final int vehicleReading, officeReading;
  final String vehicleStatus, officeStatus, gate, wifi;
  final String vehicleTestState, vehicleTestResult;
  final int vehicleResultReading;
  final bool vehicleTestActive;
  final String officeTestState, officeTestResult;
  final int officeResultReading;
  final bool officeTestActive;
  const Esp32Status({
    required this.vehicleReading,
    required this.vehicleStatus,
    required this.officeReading,
    required this.officeStatus,
    required this.gate,
    required this.wifi,
    this.vehicleTestState = 'IDLE',
    this.vehicleTestResult = 'NOT_TESTED',
    this.vehicleResultReading = 0,
    this.vehicleTestActive = false,
    this.officeTestState = 'IDLE',
    this.officeTestResult = 'NOT_TESTED',
    this.officeResultReading = 0,
    this.officeTestActive = false,
  });

  factory Esp32Status.fromJson(Map<String, dynamic> json) {
    int reading(String key) {
      final value = json[key];
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          value > 4095 ||
          value != value.toInt()) {
        throw FormatException(
          'Invalid $key: received $value (${value.runtimeType})',
        );
      }
      return value.toInt();
    }

    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException(
          'Invalid $key: received $value (${value.runtimeType})',
        );
      }
      return value;
    }

    bool flag(String key) {
      final value = json[key];
      if (value is! bool) {
        throw FormatException(
          'Invalid $key: received $value (${value.runtimeType})',
        );
      }
      return value;
    }

    final active = flag('vehicleTestActive');
    final state = text('vehicleTestState');
    final result = text('vehicleTestResult');
    if (!['IDLE', 'COUNTDOWN', 'SAMPLING', 'COMPLETED'].contains(state)) {
      throw FormatException('Invalid vehicleTestState: $state');
    }
    if (state == 'COMPLETED') {
      if (!['SAFE', 'CAUTION', 'DANGER'].contains(result)) {
        throw FormatException(
          'Invalid vehicleTestResult for COMPLETED: $result',
        );
      }
      if (active) {
        throw const FormatException(
          'Invalid vehicleTestActive: true for COMPLETED',
        );
      }
    } else if (![
      'NOT_TESTED',
      'PENDING',
      'SAFE',
      'CAUTION',
      'DANGER',
    ].contains(result)) {
      throw FormatException('Invalid vehicleTestResult for $state: $result');
    }
    return Esp32Status(
      vehicleReading: reading('vehicleReading'),
      vehicleStatus: text('vehicleStatus'),
      officeReading: reading('officeReading'),
      officeStatus: text('officeStatus'),
      gate: text('gate'),
      wifi: text('wifi'),
      vehicleTestState: state,
      vehicleTestResult: result,
      vehicleResultReading: reading('vehicleResultReading'),
      vehicleTestActive: active,
      // Older status payloads omit these fields; preserve that compatibility.
      officeTestState: json.containsKey('officeTestState')
          ? text('officeTestState')
          : 'IDLE',
      officeTestResult: json.containsKey('officeTestResult')
          ? text('officeTestResult')
          : 'NOT_TESTED',
      officeResultReading: json.containsKey('officeResultReading')
          ? reading('officeResultReading')
          : 0,
      officeTestActive: json.containsKey('officeTestActive')
          ? flag('officeTestActive')
          : false,
    );
  }
}
