# Part 9: Android emergency SMS

## Implementation

No packages added. `TestResultScreen` injects an `EmergencySmsService` into
`EmergencyAlertSection`. The section loads the contact through the existing
`UserProfileRepository`. `AndroidEmergencySmsService` uses a MethodChannel to
`EmergencySmsBridge`, which calls Android `SmsManager`. The fake service has no
platform access. Sensor sampling and classification remain unchanged.

Created files:
- `lib/models/sms_send_result.dart`
- `lib/services/emergency_sms_service.dart`
- `lib/services/android_emergency_sms_service.dart`
- `lib/services/fake_emergency_sms_service.dart`
- `lib/widgets/emergency_alert_section.dart`
- `android/app/src/main/kotlin/com/example/safestart/EmergencySmsBridge.kt`
- `test/emergency_sms_test.dart`
- `docs/PART9_SMS.md`

Modified files for Part 9:
- `lib/screens/test/test_result_screen.dart`
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/settings/emergency_contact_screen.dart`
- `android/app/src/main/kotlin/com/example/safestart/MainActivity.kt`
- `android/app/src/main/AndroidManifest.xml`
- `test/test_result_screen_test.dart`
- `test/profile_settings_test.dart`
- `test/user_profile_repository_test.dart`

Manifest additions: `android.permission.SEND_SMS` and optional
`android.hardware.telephony` (`required="false"`). No inbox, receive-SMS, or
phone-state permission was added. No iOS configuration or Gradle changes.

Only Vehicle DANGER creates the alert section. Missing contacts open the existing
editor and refresh after returning. Configured contacts appear with a confirmation
action. CANCEL sends nothing. Only SEND SMS calls the service and requests Android
permission if necessary. Denial permits another explicitly confirmed attempt;
permanent denial shows Android app-permission settings instructions.

Sending disables the action. Success requires Android's sent PendingIntent
callback with RESULT_OK; it does not establish recipient delivery. Success removes
the action for that result-screen session. Failure and denial show truthful messages
and require confirmation again. Unsupported platforms/emulators show an unavailable
state. Missing SIM/default SMS subscription and send failures are controlled errors.
A 90-second missing callback yields an unconfirmed failure with no retry button,
because sending again could duplicate the message. Status is session-only.

Settings and the contact editor now explain that permission is requested when an
alert is sent. No SMS logs or permanent history were added.

Android API references:
- https://developer.android.com/reference/android/telephony/SmsManager
- https://developer.android.com/training/permissions/requesting

## Manual device test (user initiated only)

Validation: `flutter pub get` succeeded, `flutter analyze` reported no issues,
all 71 tests passed (58 existing plus 13 added), and `flutter build apk --debug`
succeeded. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Non-blocking notices include eight newer dependency versions outside the current
constraints, existing PDF standard-font Unicode limitations, and Gradle/JVM
native-access warnings. No real SMS was sent during validation.

The normal mock reading remains 0.18 (SAFE). To reach DANGER in a local development
build, temporarily import `../../services/mock_alcohol_sensor_service.dart` into
`lib/screens/test/test_preparation_screen.dart`, and replace its `AlcoholTestScreen`
construction with:

```dart
AlcoholTestScreen(
  testType: widget.testType,
  sensorService: const MockAlcoholSensorService(simulatedReading: 0.50),
)
```

This uses the existing injection point; it does not require threshold or sampling
changes. Restore the original construction and remove the temporary import after
testing. No such change is included in Part 9.

1. Build/run that development version on a real Android phone with a ready SIM,
   SMS credit/service, and a default SMS SIM selected in Android Settings.
2. Configure an emergency contact using a number you control or a recipient who
   agreed to this test. Contact data lasts only for the current app session.
3. Complete a Vehicle test and open the DANGER result. Verify merely viewing the
   result does not request permission or send SMS.
4. Press SEND EMERGENCY ALERT, verify the name/number, then CANCEL. Nothing sends.
5. Press SEND EMERGENCY ALERT again. Only if you intend a real carrier SMS, press
   SEND SMS and grant Android's permission. Carrier charges may apply.
6. Check the sending indicator, then the actual outcome. Success means Android
   confirmed sending; check the recipient phone separately for delivery. Repeated
   taps during sending and the successful result must not send again.
7. In a fresh result session, test denying permission; retry must first ask for
   confirmation. Permanent denial should explain app settings. Test airplane mode
   or an unavailable SIM for a controlled failure (do not confirm a send unless
   you accept that the carrier could still send if service becomes available).
8. Check Office DANGER has no SMS action. SAFE and CAUTION for either test type
   also have no SMS action. A missing contact must open the editor and refresh
   the result after saving.

Automated tests use the fake or a mocked platform channel and never send a real
SMS. Physical-device permission and carrier behavior still require this manual
test. No Firebase, ESP32, MQ-3, breath detection, or relay functionality was added.
Part 6 boundaries remain 0.20 (CAUTION) and 0.40 (DANGER). Work stops at Part 9.
