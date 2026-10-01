import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'user_profile_repository.dart';
import 'firestore_codec.dart';
import 'auth_service.dart';

class MissingProfile implements Exception {}

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(
    FirebaseFirestore firestore,
    String uid,
    this.authEmail,
  ) : _document = firestore.collection('users').doc(uid);
  final DocumentReference<Map<String, dynamic>> _document;
  final String authEmail;
  @override
  bool get emailEditable => false;
  @override
  bool get isPersistent => true;
  @override
  Future<UserProfile> getProfile() async {
    final snapshot = await _document
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (!snapshot.exists) throw MissingProfile();
    return FirestoreCodec.profile(snapshot.data()!).copyWith(email: authEmail);
  }

  Future<void> createProfile(UserProfile profile) async {
    await _document.firestore
        .runTransaction((transaction) async {
          final existing = await transaction.get(_document);
          if (existing.exists) return;
          transaction.set(_document, {
            ...FirestoreCodec.profileData(profile.copyWith(email: authEmail)),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    if (profile.email != authEmail) {
      throw const AppFailure('Account email cannot be changed here.');
    }
    await _document.firestore
        .runTransaction((transaction) async {
          final existing = await transaction.get(_document);
          if (!existing.exists) throw MissingProfile();
          transaction.update(_document, {
            ...FirestoreCodec.profileData(profile),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }
}
