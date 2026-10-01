import '../models/user_profile.dart';

abstract class UserProfileRepository {
  bool get emailEditable => true;
  bool get isPersistent => false;
  Future<UserProfile> getProfile();
  Future<void> updateProfile(UserProfile profile);
}
