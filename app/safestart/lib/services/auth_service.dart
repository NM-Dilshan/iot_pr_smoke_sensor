import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

abstract class AuthService extends ChangeNotifier {
  String? get uid;
  String? get email;
  Future<void> signIn(String email, String password);
  Future<void> signUp(UserProfile profile, String password);
  Future<void> signOut();
}

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
