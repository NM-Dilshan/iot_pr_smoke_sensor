import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';
import 'firestore_user_profile_repository.dart';

String authErrorMessage(String code) => switch (code) {
  'invalid-email' => 'Enter a valid email address.',
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' => 'Email or password is incorrect.',
  'email-already-in-use' =>
    'An account already uses this email. Please sign in.',
  'weak-password' => 'Choose a stronger password with at least 6 characters.',
  'network-request-failed' =>
    'Unable to connect. Check your internet connection and try again.',
  'too-many-requests' => 'Too many attempts. Please wait and try again.',
  'user-disabled' => 'This account is disabled. Contact your administrator.',
  _ => 'Authentication could not be completed. Please try again.',
};

class FirebaseAuthService extends AuthService {
  FirebaseAuthService(this.auth, this.firestore) {
    _user = auth.currentUser;
    _subscription = auth.authStateChanges().listen((user) {
      if (_creating) return;
      _user = user;
      notifyListeners();
    });
  }
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  late final StreamSubscription<User?> _subscription;
  User? _user;
  bool _creating = false;
  @override
  String? get uid => _user?.uid;
  @override
  String? get email => _user?.email;
  @override
  Future<void> signIn(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AppFailure(authErrorMessage(error.code));
    }
  }

  @override
  Future<void> signUp(UserProfile profile, String password) async {
    _creating = true;
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: profile.email.trim(),
        password: password,
      );
      final user = credential.user!;
      try {
        await FirestoreUserProfileRepository(
          firestore,
          user.uid,
          user.email!,
        ).createProfile(profile);
      } catch (_) {
        // The Auth account exists. Keep its session so the gate can offer profile
        // recovery instead of recreating an account or admitting an incomplete profile.
        throw const AppFailure(
          'Account created, but profile setup could not finish. Complete your profile to continue.',
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AppFailure(authErrorMessage(error.code));
    } finally {
      _creating = false;
      _user = auth.currentUser;
      notifyListeners();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await auth.signOut();
      _user = null;
      notifyListeners();
    } on FirebaseAuthException catch (error) {
      throw AppFailure(authErrorMessage(error.code));
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
