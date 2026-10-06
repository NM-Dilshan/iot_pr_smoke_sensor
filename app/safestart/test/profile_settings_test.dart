import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/models/user_profile.dart';
import 'package:safestart/screens/auth/login_screen.dart';
import 'package:safestart/screens/history/history_screen.dart';
import 'package:safestart/screens/home/home_screen.dart';
import 'package:safestart/screens/profile/profile_screen.dart';
import 'package:safestart/screens/profile/edit_profile_screen.dart';
import 'package:safestart/screens/settings/settings_screen.dart';
import 'package:safestart/screens/settings/emergency_contact_screen.dart';
import 'package:safestart/services/demo_user_profile_repository.dart';
import 'package:safestart/theme/app_theme.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Profile edits validate and remain available across Settings and Home',
    (tester) async {
      final repository = DemoUserProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(profileRepository: repository),
        ),
      );
      await tap(tester, nav('Settings'));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('DEMO PROFILE'), findsOneWidget);
      expect(find.text('Not Connected'), findsOneWidget);
      expect(find.text('ESP32 Offline'), findsOneWidget);
      expect(
        find.text('SMS permission will be requested when an alert is sent.'),
        findsOneWidget,
      );
      await tap(tester, find.widgetWithText(ListTile, 'Profile'));
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Demo SafeStart User'), findsOneWidget);
      await tap(tester, find.text('EDIT PROFILE'));
      await enter(tester, 'Full Name', '');
      await enter(tester, 'Employee ID', '');
      await enter(tester, 'Email', 'bad');
      await tap(tester, find.text('SAVE CHANGES'));
      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter your employee ID.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await enter(tester, 'Full Name', 'Edited Demo');
      await enter(tester, 'Employee ID', 'DEMO-002');
      await enter(tester, 'Email', 'edited@safestart.local');
      await tap(tester, find.byType(DropdownButtonFormField<UserType>));
      await tap(tester, find.text('Driver').last);
      await tap(tester, find.text('SAVE CHANGES'));
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Edited Demo'), findsOneWidget);
      expect(find.text('User Type: Driver'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Edited Demo'), findsOneWidget);
      expect(find.text('Driver'), findsOneWidget);
      await tap(tester, nav('Home'));
      await tap(tester, find.byTooltip('Profile'));
      expect(find.text('Edited Demo'), findsOneWidget);
      expect((await repository.getProfile()).employeeId, 'DEMO-002');
    },
  );

  testWidgets(
    'Emergency contact validates, saves formatted strings and can be edited',
    (tester) async {
      final repository = DemoUserProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(profileRepository: repository),
        ),
      );
      await tap(tester, find.widgetWithText(ListTile, 'Emergency Contact'));
      expect(find.byType(EmergencyContactScreen), findsOneWidget);
      await tap(tester, find.text('SAVE EMERGENCY CONTACT'));
      expect(find.text('Enter your contact name.'), findsOneWidget);
      expect(find.text('Enter a phone number.'), findsOneWidget);
      expect(find.text('Select a relationship.'), findsOneWidget);
      await enter(tester, 'Phone Number', 'abc');
      await tap(tester, find.text('SAVE EMERGENCY CONTACT'));
      expect(find.textContaining('Enter 7'), findsOneWidget);
      await enter(tester, 'Contact Name', 'Demo Contact');
      await enter(tester, 'Phone Number', '+44 20-1234-5678');
      await tap(
        tester,
        find.byWidgetPredicate((w) => w is DropdownButtonFormField),
      );
      await tap(tester, find.text('Friend').last);
      await tap(tester, find.text('SAVE EMERGENCY CONTACT'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        (await repository.getProfile()).emergencyContact!.phoneNumber,
        '+44 20-1234-5678',
      );
      await tap(tester, nav('Settings'));
      expect(find.text('Demo Contact\n+44 20-1234-5678'), findsOneWidget);
      expect(
        find.text('SMS permission will be requested when an alert is sent.'),
        findsOneWidget,
      );
      expect(find.text('SEND TEST SMS'), findsNothing);
      await tap(tester, find.text('EDIT CONTACT'));
      expect(
        tester.widget<TextField>(field('Phone Number')).controller!.text,
        '+44 20-1234-5678',
      );
      await enter(tester, 'Phone Number', '077 123 4567');
      await tap(tester, find.text('SAVE EMERGENCY CONTACT'));
      expect(find.text('Demo Contact\n077 123 4567'), findsOneWidget);
      await tap(tester, find.widgetWithText(ListTile, 'Profile'));
      expect(find.textContaining('077 123 4567'), findsOneWidget);
      expect((await repository.getProfile()).fullName, 'Demo SafeStart User');
    },
  );

  testWidgets('About, Help, remaining tabs and logout preserve navigation', (
    tester,
  ) async {
    final repository = DemoUserProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(profileRepository: repository),
      ),
    );
    final home = tester.element(find.byType(HomeScreen));
    await tap(tester, nav('Settings'));
    await tap(tester, find.text('About SafeStart'));
    expect(find.textContaining('not a certified breathalyzer'), findsOneWidget);
    await tap(tester, find.text('CLOSE'));
    await tap(tester, find.widgetWithText(ListTile, 'Help / Instructions'));
    expect(find.textContaining('6. Use History'), findsOneWidget);
    await tap(tester, find.text('CLOSE'));
    expect(find.text('Notifications'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tap(tester, nav('History'));
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('DEMO DATA'), findsOneWidget);
    await tap(tester, nav('Settings'));
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
    await tap(tester, nav('Home'));
    expect(tester.element(find.byType(HomeScreen)), same(home));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await tap(tester, nav('Settings'));
    await tap(tester, find.text('LOG OUT'));
    expect(find.text('Log out of SafeStart?'), findsOneWidget);
    await tap(tester, find.text('CANCEL'));
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tap(tester, find.text('LOG OUT'));
    await tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('LOG OUT'),
      ),
    );
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets(
    'New forms scroll on a narrow screen with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      final repository = DemoUserProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: HomeScreen(profileRepository: repository),
        ),
      );
      await tap(tester, find.byTooltip('Profile'));
      await tap(tester, find.text('EDIT PROFILE'));
      await enter(tester, 'Email', 'edited@safestart.local');
      await tap(tester, find.text('SAVE CHANGES'));
      await tap(tester, find.text('ADD CONTACT'));
      await enter(tester, 'Phone Number', '+1-202-555-0123');
      await tap(tester, find.text('SAVE EMERGENCY CONTACT'));
      expect(tester.takeException(), isNull);
    },
  );
}
