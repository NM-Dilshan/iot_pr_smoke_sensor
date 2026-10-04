import 'support/fakes.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestart/main.dart';
import 'package:safestart/screens/auth/login_screen.dart';
import 'package:safestart/screens/auth/signup_screen.dart';
import 'package:safestart/screens/home/home_screen.dart';
import 'package:safestart/screens/splash/splash_screen.dart';
import 'package:safestart/theme/app_theme.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Splash advances to login after 2.6 seconds', (tester) async {
    await tester.pumpWidget(
      SafeStartApp(
        initialize: () async =>
            MaterialApp(home: LoginScreen(auth: FakeAuthService())),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('Disposing splash cancels pending navigation', (tester) async {
    await tester.pumpWidget(
      SafeStartApp(
        initialize: () async =>
            MaterialApp(home: LoginScreen(auth: FakeAuthService())),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Login validates, toggles password, and opens the demo dashboard',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(auth: FakeAuthService()),
        ),
      );
      await tapVisible(tester, find.text('SIGN IN'));
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      await enter(tester, 'Email', 'alex@example.com');
      await enter(tester, 'Password', '123');
      await tapVisible(tester, find.text('SIGN IN'));
      expect(find.text('Use at least 6 characters.'), findsOneWidget);
      await enter(tester, 'Password', 'secret1');
      final password = find.descendant(
        of: field('Password'),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(password).obscureText, isTrue);
      await tapVisible(tester, find.byTooltip('Show password'));
      expect(tester.widget<EditableText>(password).obscureText, isFalse);
      await tapVisible(tester, find.text('Forgot Password?'));
      expect(find.text('Password reset is not available yet.'), findsOneWidget);
      await tapVisible(tester, find.text('SIGN IN'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('ESP32 Offline'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets(
    'Signup validates all fields and terms, then returns with success',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(auth: FakeAuthService()),
        ),
      );
      await tapVisible(tester, find.text('Create Account'));
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Employee'))
            .selected,
        isTrue,
      );
      await tapVisible(tester, find.text('CREATE ACCOUNT'));
      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter your employee ID.'), findsOneWidget);
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(find.text('Confirm your password.'), findsOneWidget);
      expect(
        find.text('Please agree to the Terms & Privacy Policy.'),
        findsOneWidget,
      );
      await enter(tester, 'Full Name', 'Alex Smith');
      await enter(tester, 'Employee ID', 'EMP001');
      await enter(tester, 'Email', 'invalid');
      await enter(tester, 'Password', '123');
      await enter(tester, 'Confirm Password', 'different');
      await tapVisible(tester, find.text('CREATE ACCOUNT'));
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 6 characters.'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await enter(tester, 'Email', 'alex@example.com');
      await enter(tester, 'Password', 'secret1');
      await enter(tester, 'Confirm Password', 'secret1');
      await tapVisible(tester, find.byTooltip('Show confirm password'));
      final confirmation = find.descendant(
        of: field('Confirm Password'),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(confirmation).obscureText, isFalse);
      await tapVisible(tester, find.text('Driver'));
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Driver'))
            .selected,
        isTrue,
      );
      await tapVisible(tester, find.text('CREATE ACCOUNT'));
      expect(find.byType(SignupScreen), findsOneWidget);
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.text('CREATE ACCOUNT'));
      expect(find.byType(SignupScreen), findsNothing);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Account created successfully'), findsOneWidget);
    },
  );

  testWidgets('Signup sign in link returns without creating an account', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LoginScreen(auth: FakeAuthService()),
      ),
    );
    await tapVisible(tester, find.text('Create Account'));
    await tapVisible(tester, find.text('SIGN IN'));
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Account created successfully'), findsNothing);
  });

  testWidgets('Forms scroll on a narrow screen with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LoginScreen(auth: FakeAuthService()),
      ),
    );
    await enter(tester, 'Password', 'secret1');
    await tapVisible(tester, find.text('Create Account'));
    await enter(tester, 'Confirm Password', 'secret1');
    await tapVisible(tester, find.text('CREATE ACCOUNT'));
    expect(tester.takeException(), isNull);
    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
