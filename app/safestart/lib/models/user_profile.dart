import 'emergency_contact.dart';

enum UserType {
  employee,
  driver;

  String get label => name[0].toUpperCase() + name.substring(1);
}

class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.employeeId,
    required this.email,
    required this.userType,
    this.emergencyContact,
  });

  final String fullName;
  final String employeeId;
  final String email;
  final UserType userType;
  final EmergencyContact? emergencyContact;

  UserProfile copyWith({
    String? fullName,
    String? employeeId,
    String? email,
    UserType? userType,
    EmergencyContact? emergencyContact,
  }) => UserProfile(
    fullName: fullName ?? this.fullName,
    employeeId: employeeId ?? this.employeeId,
    email: email ?? this.email,
    userType: userType ?? this.userType,
    emergencyContact: emergencyContact ?? this.emergencyContact,
  );
}
