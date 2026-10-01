import '../models/alcohol_test_result.dart';

abstract class TestHistoryRepository {
  Future<List<AlcoholTestResult>> getResults();
  Future<void> saveResult(String id, AlcoholTestResult result);
}
