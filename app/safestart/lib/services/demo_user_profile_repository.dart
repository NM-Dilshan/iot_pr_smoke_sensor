import '../models/user_profile.dart';
import 'user_profile_repository.dart';

/// Session-only memory. Restarting the app restores this neutral demo profile.
/// Mock logout changes navigation only; no credentials or cloud data exist.
class DemoUserProfileRepository extends UserProfileRepository {
  static final UserProfileRepository session = DemoUserProfileRepository();

  UserProfile _profile = const UserProfile(
    fullName: 'Demo SafeStart User',
    employeeId: 'DEMO-001',
    email: 'demo@safestart.local',
    userType: UserType.employee,
  );

  @override
  Future<UserProfile> getProfile() async => _profile;

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
  }
}
