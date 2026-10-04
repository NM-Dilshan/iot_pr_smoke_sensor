import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../models/emergency_contact.dart';
import '../models/alcohol_test_result.dart';
import '../models/test_type.dart';
import '../models/safety_status.dart';
import 'alcohol_classification_service.dart';

class FirestoreCodec {
  static String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $key');
    }
    return value;
  }

  static T _enum<T extends Enum>(List<T> values, Object? value) =>
      values.firstWhere(
        (entry) => entry.name == value,
        orElse: () => throw const FormatException('Unknown enum value'),
      );
  static UserProfile profile(Map<String, dynamic> data) {
    final contact = data['emergencyContact'];
    return UserProfile(
      fullName: _string(data, 'fullName'),
      employeeId: _string(data, 'employeeId'),
      email: _string(data, 'email'),
      userType: _enum(UserType.values, data['userType']),
      emergencyContact: contact == null
          ? null
          : emergencyContact(Map<String, dynamic>.from(contact as Map)),
    );
  }

  static EmergencyContact emergencyContact(Map<String, dynamic> data) =>
      EmergencyContact(
        name: _string(data, 'name'),
        phoneNumber: _string(data, 'phoneNumber'),
        relationship:
            ContactRelationship.values
                .where((r) => r.name == data['relationship'])
                .firstOrNull ??
            ContactRelationship.other,
      );
  static Map<String, dynamic> profileData(UserProfile profile) => {
    'fullName': profile.fullName,
    'employeeId': profile.employeeId,
    'email': profile.email,
    'userType': profile.userType.name,
    'emergencyContact': profile.emergencyContact == null
        ? null
        : {
            'name': profile.emergencyContact!.name,
            'phoneNumber': profile.emergencyContact!.phoneNumber,
            'relationship': profile.emergencyContact!.relationship.name,
          },
  };
  static Map<String, dynamic> resultData(AlcoholTestResult result) {
    if (!result.sensorReading.isFinite ||
        result.sensorReading < 0 ||
        (result.isEsp32Hardware &&
            ((result.isEsp32Vehicle && result.testType != TestType.vehicle) ||
                (result.isEsp32Office && result.testType != TestType.office) ||
                result.sensorReading > 4095 ||
                result.sensorReading !=
                    result.sensorReading.truncateToDouble()))) {
      throw const FormatException('Invalid sensor reading');
    }
    if (!result.isEsp32Hardware &&
        const AlcoholClassificationService().classify(result.sensorReading) !=
            result.status) {
      throw const FormatException('Invalid classification');
    }
    return {
      'testType': result.testType.name,
      'sensorReading': result.sensorReading,
      'status': result.status.name,
      'timestamp': Timestamp.fromDate(result.timestamp),
      'source': result.isEsp32Vehicle
          ? 'esp32_vehicle'
          : result.isEsp32Office
          ? 'esp32_office'
          : 'simulation',
      'isPrototype': true,
    };
  }

  static AlcoholTestResult result(Map<String, dynamic> data) {
    final time = data['timestamp'];
    final date = time is Timestamp
        ? time.toDate()
        : time is DateTime
        ? time
        : null;
    final reading = data['sensorReading'];
    if (date == null ||
        reading is! num ||
        !reading.isFinite ||
        reading < 0 ||
        (data['source'] != null &&
            data['source'] != 'simulation' &&
            data['source'] != 'esp32_vehicle' &&
            data['source'] != 'esp32_office') ||
        (data['isPrototype'] != null && data['isPrototype'] != true)) {
      throw const FormatException('Malformed prototype record');
    }
    final result = AlcoholTestResult(
      testType: _enum(TestType.values, data['testType']),
      sensorReading: reading.toDouble(),
      status: _enum(SafetyStatus.values, data['status']),
      timestamp: date,
      isEsp32Vehicle: data['source'] == 'esp32_vehicle',
      isEsp32Office: data['source'] == 'esp32_office',
    );
    resultData(result);
    return result;
  }
}
