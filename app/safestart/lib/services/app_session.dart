import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'user_profile_repository.dart';
import 'test_history_repository.dart';

class AppSession extends InheritedWidget {
  const AppSession({
    super.key,
    required this.auth,
    required this.profiles,
    required this.history,
    required this.changes,
    required super.child,
  });
  final AuthService auth;
  final UserProfileRepository profiles;
  final TestHistoryRepository history;
  final SessionChanges changes;
  static AppSession? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppSession>();
  @override
  bool updateShouldNotify(AppSession oldWidget) =>
      profiles != oldWidget.profiles;
}

class SessionChanges extends ValueNotifier<int> {
  SessionChanges() : super(0);
  bool _disposed = false;
  void refresh() {
    if (!_disposed) value++;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
