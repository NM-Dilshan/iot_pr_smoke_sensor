import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safestart/main.dart';
import 'package:safestart/models/alcohol_test_result.dart';
import 'package:safestart/models/emergency_contact.dart';
import 'package:safestart/models/safety_status.dart';
import 'package:safestart/models/test_type.dart';
import 'package:safestart/models/user_profile.dart';
import 'package:safestart/services/app_session.dart';
import 'package:safestart/services/auth_service.dart';
import 'package:safestart/services/completed_test_save.dart';
import 'package:safestart/services/demo_user_profile_repository.dart';
import 'package:safestart/services/firestore_codec.dart';
import 'package:safestart/services/firebase_auth_service.dart';
import 'package:safestart/screens/auth/session_gate.dart';
import 'package:safestart/screens/auth/login_screen.dart';
import 'package:safestart/screens/home/home_screen.dart';
import 'package:safestart/screens/history/history_screen.dart';
import 'package:safestart/screens/test/alcohol_test_screen.dart';
import 'package:safestart/services/mock_alcohol_sensor_service.dart';
import 'package:safestart/widgets/stored_dashboard.dart';
import 'package:safestart/widgets/dashboard_stat_card.dart';
import 'package:safestart/screens/test/test_result_screen.dart';
import 'package:safestart/services/fake_emergency_sms_service.dart';

import 'support/fakes.dart';

final sample = AlcoholTestResult(
  testType: TestType.vehicle,
  sensorReading: 0.5,
  status: SafetyStatus.danger,
  timestamp: DateTime(2026, 10, 1),
);
Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Widget session(Widget child, MemoryHistory history) => AppSession(
  auth: FakeAuthService(userId: 'test-user'),
  profiles: DemoUserProfileRepository(),
  history: history,
  changes: SessionChanges(),
  child: MaterialApp(home: child),
);

void main() {
  testWidgets('dashboard refreshes when stored results change', (tester) async {
    final history = MemoryHistory();
    final changes = SessionChanges();
    final scope = AppSession(
      auth: FakeAuthService(userId: 'test-user'),
      profiles: DemoUserProfileRepository(),
      history: history,
      changes: changes,
      child: Builder(
        builder: (context) => MaterialApp(
          home: Scaffold(
            body: StoredDashboard(session: AppSession.maybeOf(context)!),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DashboardStatCard>(find.byType(DashboardStatCard).first)
          .value,
      0,
    );
    history.records['one'] = AlcoholTestResult(
      testType: TestType.vehicle,
      sensorReading: 0.5,
      status: SafetyStatus.danger,
      timestamp: DateTime.now(),
    );
    changes.refresh();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DashboardStatCard>(find.byType(DashboardStatCard).first)
          .value,
      1,
    );
    expect(
      tester
          .widget<DashboardStatCard>(find.byType(DashboardStatCard).last)
          .value,
      1,
    );
  });
  testWidgets(
    'result reads latest contact from session repository without sending',
    (tester) async {
      final profiles = DemoUserProfileRepository();
      await profiles.updateProfile(
        (await profiles.getProfile()).copyWith(
          emergencyContact: const EmergencyContact(
            name: 'Stored Contact',
            phoneNumber: '+94770000000',
            relationship: ContactRelationship.family,
          ),
        ),
      );
      final sms = FakeEmergencySmsService();
      await tester.pumpWidget(
        AppSession(
          auth: FakeAuthService(userId: 'test-user'),
          profiles: profiles,
          history: MemoryHistory(),
          changes: SessionChanges(),
          child: MaterialApp(
            home: TestResultScreen(result: sample, smsService: sms),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stored Contact'), findsOneWidget);
      expect(find.text('+94770000000'), findsOneWidget);
      expect(sms.calls, 0);
    },
  );
  testWidgets(
    'sign up through fake auth enters authenticated app with profile fields',
    (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        SessionGate(
          auth: auth,
          profiles: (_) => DemoUserProfileRepository(),
          history: (_) => MemoryHistory(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tap(tester, 'Create Account');
      for (final entry in {
        'Full Name': 'New User',
        'Employee ID': 'EMP-NEW',
        'Email': 'new@example.com',
        'Password': 'secret123',
        'Confirm Password': 'secret123',
      }.entries) {
        final finder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.key,
        );
        await tester.ensureVisible(finder);
        await tester.enterText(finder, entry.value);
      }
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tap(tester, 'CREATE ACCOUNT');
      expect(auth.createdProfile!.employeeId, 'EMP-NEW');
      expect(auth.createdProfile!.fullName, 'New User');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen, skipOffstage: false), findsNothing);
    },
  );
  test(
    'Firestore result roundtrip preserves prototype metadata and timestamp',
    () {
      final data = FirestoreCodec.resultData(sample);
      expect(data['source'], 'simulation');
      expect(data['isPrototype'], true);
      expect(data['timestamp'], isA<Timestamp>());
      final result = FirestoreCodec.result(data);
      expect(result.timestamp, sample.timestamp);
      expect(result.status, SafetyStatus.danger);
      expect(result.sensorReading, 0.5);
      expect(result.testType, TestType.vehicle);
      expect(
        FirestoreCodec.result({...data, 'timestamp': sample.timestamp})
            .timestamp,
        sample.timestamp,
      );
    },
  );
  test('invalid records never become plausible SAFE history', () {
    final data = FirestoreCodec.resultData(sample);
    for (final patch in [
      <String, dynamic>{'status': 'unknown'},
      {'testType': 'unknown'},
      {'sensorReading': double.nan},
      {'timestamp': null},
      {'status': 'safe'},
      {'source': 'hardware'},
    ]) {
      expect(
        () => FirestoreCodec.result({...data, ...patch}),
        throwsFormatException,
      );
    }
  });
  test('profile/contact serialization excludes credentials and handles null contact', () {
    const profile = UserProfile(
      fullName: 'Alex',
      employeeId: 'EMP1',
      email: 'alex@example.com',
      userType: UserType.driver,
      emergencyContact: EmergencyContact(
        name: 'Family',
        phoneNumber: '+94771234567',
        relationship: ContactRelationship.family,
      ),
    );
    final data = FirestoreCodec.profileData(profile);
    expect(data.keys, isNot(contains('password')));
    expect(
      FirestoreCodec.profile(data).emergencyContact!.phoneNumber,
      '+94771234567',
    );
    expect(
      FirestoreCodec.profile({...data, 'emergencyContact': null})
          .emergencyContact,
      isNull,
    );
    expect(
      FirestoreCodec.emergencyContact({
        'name': 'A',
        'phoneNumber': '1234567',
        'relationship': 'legacy',
      }).relationship,
      ContactRelationship.other,
    );
  });
  test('concurrent save and retries use one stable record id', () async {
    final history = MemoryHistory();
    final pending = Completer<void>();
    history.pending = pending.future;
    final save = CompletedTestSave(history, sample);
    final first = save.save();
    await save.save();
    expect(history.attempts.length, 1);
    pending.complete();
    await first;
    await save.save();
    expect(history.records.length, 1);
    expect(save.state, TestSaveState.saved);
    final retry = CompletedTestSave(history, sample);
    history.fail = true;
    await retry.save();
    expect(retry.state, TestSaveState.failed);
    history.fail = false;
    await retry.save();
    expect(
      history.attempts.last,
      history.attempts[history.attempts.length - 2],
    );
    expect(history.records.length, 2);
  });
  test('common auth errors have friendly messages', () {
    for (final code in [
      'invalid-email',
      'invalid-credential',
      'email-already-in-use',
      'weak-password',
      'network-request-failed',
      'too-many-requests',
      'unknown',
    ]) {
      expect(authErrorMessage(code), isNotEmpty);
      expect(authErrorMessage(code), isNot(contains('FirebaseException')));
    }
  });
  testWidgets('initialization failure offers retry instead of stuck splash', (
    tester,
  ) async {
    await tester.pumpWidget(
      SafeStartApp(initialize: () async => throw StateError('offline')),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.textContaining('could not connect'), findsOneWidget);
  });
  testWidgets('login failure stays on login with useful error', (tester) async {
    final auth = FakeAuthService()
      ..failure = const AppFailure('Email or password is incorrect.');
    await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
    await tester.enterText(
      find.byType(TextFormField).first,
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret1');
    await tap(tester, 'SIGN IN');
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
  testWidgets(
    'auth routing restores session and logout destroys protected stack',
    (tester) async {
      final auth = FakeAuthService(userId: 'test-user');
      await tester.pumpWidget(
        SessionGate(
          auth: auth,
          profiles: (_) => DemoUserProfileRepository(),
          history: (_) => MemoryHistory(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('DEMO / SAMPLE VALUES'), findsNothing);
      await tap(tester, 'Settings');
      await tap(tester, 'LOG OUT');
      await tap(tester, 'LOG OUT');
      expect(auth.signOutCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        false,
      );
    },
  );
  testWidgets('production history is empty without injecting demo records', (
    tester,
  ) async {
    await tester.pumpWidget(session(const HistoryScreen(), MemoryHistory()));
    await tester.pumpAndSettle();
    expect(find.text('No saved test records yet.'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsNothing);
  });
  testWidgets(
    'completion saves before navigation, revisiting does not duplicate',
    (tester) async {
      final history = MemoryHistory();
      await tester.pumpWidget(
        session(const AlcoholTestScreen(testType: TestType.office), history),
      );
      expect(history.records, isEmpty);
      await tap(tester, 'START TEST');
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(history.records.length, 1);
      expect(history.attempts.length, 1);
      await tap(tester, 'VIEW RESULT');
      expect(find.text('Test result saved.'), findsOneWidget);
      expect(history.records.length, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'VIEW RESULT');
      expect(history.attempts.length, 1);
    },
  );
  testWidgets('incomplete and cancelled tests do not save', (tester) async {
    final history = MemoryHistory();
    await tester.pumpWidget(
      session(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const AlcoholTestScreen(testType: TestType.vehicle),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        history,
      ),
    );
    await tap(tester, 'Open');
    await tap(tester, 'START TEST');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tap(tester, 'CANCEL TEST');
    expect(history.records, isEmpty);
    expect(history.attempts, isEmpty);
  });
  testWidgets('failed sampling never saves', (tester) async {
    final history = MemoryHistory();
    await tester.pumpWidget(
      session(
        const AlcoholTestScreen(
          testType: TestType.vehicle,
          sensorService: MockAlcoholSensorService(simulatedReading: -1),
        ),
        history,
      ),
    );
    await tap(tester, 'START TEST');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(history.attempts, isEmpty);
    expect(find.text('VIEW RESULT'), findsNothing);
  });
}
