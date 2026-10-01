import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/emergency_contact.dart';
import 'package:safestart/models/user_profile.dart';
import 'package:safestart/services/demo_user_profile_repository.dart';
import 'package:safestart/services/profile_validators.dart';

void main() {
  test('Repository starts neutral and retains updates only in its session instance', () async {
    final repository = DemoUserProfileRepository();
    final original = await repository.getProfile();
    expect(original.fullName, 'Demo SafeStart User');
    expect(original.employeeId, 'DEMO-001');
    expect(original.email, 'demo@safestart.local');
    expect(original.userType, UserType.employee);
    expect(original.emergencyContact, isNull);
    const contact = EmergencyContact(
      name: 'Demo Contact',
      phoneNumber: '+44 20-1234-5678',
      relationship: ContactRelationship.friend,
    );
    await repository.updateProfile(
      original.copyWith(emergencyContact: contact),
    );
    final withContact = await repository.getProfile();
    await repository.updateProfile(
      withContact.copyWith(
        fullName: 'Edited Demo User',
        userType: UserType.driver,
      ),
    );
    final updated = await repository.getProfile();
    expect(updated.fullName, 'Edited Demo User');
    expect(updated.emergencyContact!.phoneNumber, '+44 20-1234-5678');
    expect(
      (await DemoUserProfileRepository().getProfile()).fullName,
      original.fullName,
    );
    expect(
      (await DemoUserProfileRepository().getProfile()).emergencyContact,
      isNull,
    );
  });

  test('Phone validation accepts basic international formatting and rejects malformed input', () {
    for (final phone in [
      '+44 20-1234-5678',
      '077 123 4567',
      '+1-202-555-0123',
      '00123456789',
      '1234567',
    ]) {
      expect(ProfileValidators.phone(phone), isNull);
    }
    for (final phone in [
      '',
      ' ',
      '123',
      'abc1234567',
      '++123456789',
      '123+456789',
      '1234567890123456',
    ]) {
      expect(ProfileValidators.phone(phone), isNotNull);
    }
  });

  test('Android requests only SEND_SMS, never inbox permissions', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android.permission.SEND_SMS'),
    );
    final manifests = Directory('android/app/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('AndroidManifest.xml'));
    for (final manifest in manifests) {
      final content = manifest.readAsStringSync();
      expect(content, isNot(contains('android.permission.READ_SMS')));
      expect(content, isNot(contains('android.permission.RECEIVE_SMS')));
    }
  });
}
