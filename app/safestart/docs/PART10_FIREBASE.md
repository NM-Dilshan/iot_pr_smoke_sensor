# Part 10: Firebase Authentication and Firestore

## Configuration and packages

The existing `google-services.json`, generated `firebase_options.dart`, and Google
Services Gradle configuration are preserved. Android package remains
`com.example.safestart`; the only production Firebase target is `safestart-95914`.
No new Firebase project was created.

Direct Flutter dependencies added:

| Package | Resolved version |
| --- | --- |
| firebase_core | 4.15.0 |
| firebase_auth | 6.7.0 |
| cloud_firestore | 6.10.0 |

Unrelated dependencies were not upgraded. The manifest now declares INTERNET for
Firebase in all build modes. SEND_SMS and the Part 9 native bridge are preserved.
`kotlin.incremental=false` in `android/gradle.properties` fixes the observed Windows
build failure when plugin source files are on C: and this project is on E:.

## Authentication and startup

`main.dart` initializes Firebase with `DefaultFirebaseOptions.currentPlatform`.
The startup future is shared across retries to avoid overlapping initialization.
Splash is shown for at least 2.6 seconds; a startup failure/25-second timeout shows
a retry action instead of leaving the app on Splash.

`AuthService` separates UI from Firebase and allows fake authentication in tests.
`FirebaseAuthService` uses Email/Password sign-in, signup, auth-state changes, and
sign-out. Login now requires email, not employee ID. The existing UI/validation is
preserved with loading guards and friendly authentication error messages.

Signup creates the Auth account, then its UID-addressed profile. Passwords are
passed only to Auth, never serialized or stored in Firestore. Auth navigation is
held while creating the profile. If only account creation succeeds, the session
gate blocks dashboard access and offers profile completion/retry. A restored
Firebase session enters the gate without forcing another login. Logout retains
the confirmation and replaces the entire protected navigator, so Back cannot
reopen protected routes.

## Profile and contact

`FirestoreUserProfileRepository` implements the existing repository abstraction:

```text
users/{uid}
  fullName, employeeId, email, userType
  createdAt, updatedAt                 (server timestamps)
  emergencyContact: null | {name, phoneNumber, relationship}
```

Authenticated email is read-only in profile editing. The repository and rules
also reject changing it independently of Firebase Auth. Other profile fields and
emergency contacts persist through the repository. Reads request current server
data; offline/read failures show retry states rather than substituting demo data.
Writes use transactions and bounded waits. Profile/contact saves preserve the
other fields, and edits refresh the dashboard profile display.

## Completed tests, history, dashboard, analytics and reports

Sampling remains simulated. Once valid sampling and classification finish,
`VIEW RESULT` is the deliberate save point. Merely opening screens, countdowns,
cancelled/abandoned attempts, and failed sampling do not save. A
`CompletedTestSave` belongs to the sampling run, not a widget rebuild. It assigns
one random ID and retains that ID across retries and revisiting the result.
The repository's create-once transaction also protects against uncertain network
outcomes. Result UI shows saving, saved, or failed with RETRY SAVE. Wait for
`Test result saved.` before closing the result if you want confirmation.

```text
users/{uid}/tests/{testId}
  testType: vehicle | office
  sensorReading: number
  status: safe | caution | danger
  timestamp: Timestamp                (completed sampling time)
  source: simulation
  isPrototype: true
```

`FirestoreTestHistoryRepository` loads only the signed-in user's collection.
The 48 demo records remain available for existing offline tests and isolated
development screens; the authenticated app never falls back to them. Empty
production history says `No saved test records yet.`

Existing Daily/Weekly/Monthly/custom and All/Vehicle/Office filters and analytics
operate on the loaded records. Production periods use today's date rather than
the latest demo date. Dashboard cards show today's stored tests and classification
counts, with zero for an empty account. Successful saves refresh dashboard and
open history views. Recent activity shows the most recent stored records.

PDFs use a snapshot of the selected filter and records, plus the current profile's
full name and employee ID. Existing summaries, prototype statistics, individual
records, and disclaimer remain. Production report labels no longer claim demo
fixtures. Serialization is centralized in `FirestoreCodec`, including enum,
Timestamp/DateTime, and nullable-contact handling. Unknown/malformed test data
fails visibly instead of becoming a fabricated SAFE reading or silently skewing
analytics. Unknown contact relationships fall back to Other.

## Part 9 and scope

Vehicle DANGER resolves the latest contact through the session profile repository.
No persistence callback sends SMS. The existing explicit SEND EMERGENCY ALERT,
confirmation, SEND SMS, permission, and native sent-callback flow remains. Office
results never expose emergency SMS. Automated tests use fake SMS or a mocked
channel and no real SMS was sent.

No Firebase SMS logs, hardware, ESP32, MQ-3, airflow/pressure sensor, breath
detection, relay, buzzer, LED logic, or calibration were added. The existing
temporary prototype thresholds remain `<0.20 SAFE`, `0.20–<0.40 CAUTION`, and
`>=0.40 DANGER`. All stored tests are marked simulation/prototype. Part 11 was
not implemented.

## Security rules and deployment

The exact rules are in `firestore.rules`, referenced by `firebase.json`. They
require the authenticated UID to match the requested user path, reject anonymous
and cross-user access, restrict profile/test fields, prohibit credentials, keep
profile email consistent with Auth, preserve createdAt, and allow only correctly
classified simulation records. Existing test records are immutable. No public
read/write rule exists. The current userType field is descriptive, not an
authorization role.

Target verification succeeded with:

```powershell
firebase use --project safestart-95914
```

**Production deployment succeeded on 1 October 2026 at 21:07 Asia/Colombo**, after
explicit user approval. Firebase compiled the unchanged file, updated the
`projects/safestart-95914/releases/cloud.firestore` release, and returned
`Deploy complete!` with exit code 0. No deployment errors occurred; the existing
informational FlutterFire configuration-key warning remained.

Ruleset: `a9a92bf0-9166-46b5-8ca4-a3ac2d60cec7`.
SHA-256 before and after deployment:
`FD6109FF18E172AFC7130947A9A5BC8DF21FB3ACB976036FE8EF65519C21D32E`.
Only Firestore rules were deployed; no other project or Firebase configuration
was deployed. Command used:

```powershell
firebase deploy --only firestore:rules --project safestart-95914 --non-interactive
```

Manual alternative:
1. Open Firebase Console and select **SafeStart / safestart-95914**.
2. Open **Build > Firestore Database**, database **(default)**, then **Rules**.
3. Replace the editor contents with the exact contents of this project's
   `firestore.rules`. Review UID ownership and field validation.
4. Click **Publish**. Do not change rules for any other Firebase project.

Local rules testing uses `firebase.emulator.json` and the fake ID `demo-safestart`.
It creates no real project and does not deploy anything. The Node test has no npm
dependencies and refuses a non-local emulator host:

```powershell
firebase emulators:exec --only firestore --project demo-safestart --config firebase.emulator.json "node test/firestore_rules_test.mjs"
```

## Manual Firebase validation

Complete rules deployment first, then install/run the debug APK on Android with
internet access. No automated test creates a live Firebase user.

1. **Signup:** Create a test account with your own email in SafeStart. In Firebase
   Console > Authentication > Users, confirm that user and copy its UID.
2. **Profile:** In Firestore > Data > users > UID, verify name, employee ID, email,
   userType and server timestamps. Confirm no password fields exist.
3. **Edit/contact:** Edit the name/employee ID/type and emergency contact. Verify
   Firestore updates and email stays read-only. Restart and verify stored values.
4. **Session/logout:** Close/restart the app while signed in; it should restore
   the session. Confirm logout returns to Login and Back cannot reopen Home.
5. **Test save:** Run a simulated Vehicle or Office test, finish sampling, and
   press VIEW RESULT. Wait for `Test result saved.` Verify exactly one document
   in users/UID/tests, including `source=simulation` and `isPrototype=true`.
   Return to and reopen the same result; no duplicate should appear. Cancel a
   separate test during countdown/sampling and verify nothing is written.
6. **History:** Check the stored record and Daily/Weekly/Monthly/custom/type
   filters. A new account without tests must have empty history, not demo records.
7. **Dashboard:** After a saved test, return Home and verify today's counts and
   recent activity refresh. Profile edits should also refresh the greeting.
8. **PDF:** Choose a history filter, generate a report, and verify the name,
   employee ID, period, matching records, analytics and prototype disclaimer.
9. **Errors:** With networking disabled, try reads/saves and confirm a retryable
   error rather than fabricated data. Restore networking and retry the same test
   save; the stable ID must prevent a duplicate.
10. **SMS/contact only:** To reach Vehicle DANGER, use the temporary development
    injection described in `docs/PART9_SMS.md`. Verify the Firestore contact is
    shown. CANCEL the SMS confirmation; do not send a real SMS during validation.
    Office DANGER must have no SMS action. Restore normal mock injection afterward.

## Files created

- `lib/services/auth_service.dart`, `firebase_auth_service.dart`, `app_session.dart`
- `lib/services/firestore_codec.dart`, `firestore_user_profile_repository.dart`,
  `firestore_test_history_repository.dart`, `completed_test_save.dart`
- `lib/screens/auth/session_gate.dart`
- `lib/widgets/stored_dashboard.dart`, `test_save_status.dart`
- `firestore.rules`, `firebase.emulator.json`
- `test/support/fakes.dart`, `test/firebase_persistence_test.dart`,
  `test/firestore_rules_test.mjs`
- `docs/PART10_FIREBASE.md`

## Files modified for Part 10

- `pubspec.yaml`, `pubspec.lock`, `firebase.json`
- `android/gradle.properties`, `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart`, `lib/screens/splash/splash_screen.dart`
- `lib/screens/auth/login_screen.dart`, `signup_screen.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/test/alcohol_test_screen.dart`, `test_result_screen.dart`
- `lib/screens/history/history_screen.dart`, `history_detail_sheet.dart`,
  `report_preview_screen.dart`
- `lib/screens/profile/edit_profile_screen.dart`
- `lib/screens/settings/settings_screen.dart`, `emergency_contact_screen.dart`
- `lib/models/history_report.dart`
- `lib/services/user_profile_repository.dart`, `demo_user_profile_repository.dart`,
  `test_history_repository.dart`, `demo_test_history_repository.dart`, `report_service.dart`
- `lib/widgets/profile_page.dart`
- `test/widget_test.dart`, `history_screen_test.dart`, `report_service_test.dart`

Existing user Firebase configuration and earlier Parts 1–9 files were retained.

## Validation and remaining actions

- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: **87 tests passed**, preserving the earlier 71 tests and adding
  15 Firebase/persistence tests and one stored-report test.
- Local Firestore emulator: **15 rule checks passed**, including owner access,
  anonymous/cross-user denial, contact updates, email consistency, rejecting
  passwords, record immutability, and rejecting false classification/hardware claims.
- `flutter build apk --debug`: passed after the Windows Kotlin cache fix.
  Output: `build/app/outputs/flutter-apk/app-debug.apk`.
- No live Auth account/test documents were created and no real SMS was sent.
- Rules are published to **safestart-95914**. Remaining: perform the manual
  Firebase/Android checks above. Production connectivity/session restoration has
  not been exercised with a live account during automated validation.

Non-blocking warnings: eight unrelated newer package versions; existing PDF
Helvetica Unicode limitations; JVM native-access warnings; Firebase Auth/Core
plugins still using KGP, which future Flutter versions may reject; Firestore
Java unchecked-operation notices. The initial compilation also warned about
plugin Java 8 source/target settings. Firebase CLI emits an informational warning
for FlutterFire's existing `flutter` key in `firebase.json`; it was preserved.

## References

- [Flutter Firebase Auth](https://firebase.google.com/docs/auth/flutter/start)
- [Firestore writes and timestamps](https://firebase.google.com/docs/firestore/manage-data/add-data)
- [Security Rules ownership patterns](https://firebase.google.com/docs/rules/basics)
