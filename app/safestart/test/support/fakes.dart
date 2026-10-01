import 'package:safestart/services/auth_service.dart';
import 'package:safestart/services/test_history_repository.dart';
import 'package:safestart/models/user_profile.dart';
import 'package:safestart/models/alcohol_test_result.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({this.userId});
  String? userId;
  AppFailure? failure;
  UserProfile? createdProfile;
  int signInCalls = 0, signOutCalls = 0;
  @override
  String? get uid => userId;
  @override
  String? get email => 'alex@example.com';
  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (failure != null) throw failure!;
    userId = 'test-user';
    notifyListeners();
  }

  @override
  Future<void> signUp(UserProfile profile, String password) async {
    if (failure != null) throw failure!;
    createdProfile = profile;
    userId = 'test-user';
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    userId = null;
    notifyListeners();
  }
}

class MemoryHistory implements TestHistoryRepository {
  final Map<String, AlcoholTestResult> records = {};
  final List<String> attempts = [];
  bool fail = false;
  Future<void>? pending;
  @override
  Future<List<AlcoholTestResult>> getResults() async =>
      records.values.toList().reversed.toList();
  @override
  Future<void> saveResult(String id, AlcoholTestResult result) async {
    attempts.add(id);
    if (pending != null) await pending;
    if (fail) throw StateError('offline');
    records.putIfAbsent(id, () => result);
  }
}
