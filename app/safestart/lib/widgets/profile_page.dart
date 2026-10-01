import 'package:flutter/material.dart';

import '../services/app_session.dart';

import '../theme/app_colors.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.title,
    required this.child,
    this.bottomNavigationBar,
  });
  final String title;
  final Widget child;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    bottomNavigationBar: bottomNavigationBar,
    body: SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppSession.maybeOf(context) == null
                      ? 'DEMO PROFILE'
                      : 'YOUR ACCOUNT',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppSession.maybeOf(context) == null
                      ? 'Changes last only for this app session. Cloud storage is not connected.'
                      : 'Profile and emergency contact are stored in your account.',
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
