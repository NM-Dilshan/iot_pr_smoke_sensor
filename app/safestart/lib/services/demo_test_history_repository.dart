import '../models/alcohol_test_result.dart';
import '../models/test_type.dart';
import 'alcohol_classification_service.dart';
import 'test_history_repository.dart';

class DemoTestHistoryRepository implements TestHistoryRepository {
  @override
  Future<void> saveResult(String id, AlcoholTestResult result) async =>
      throw UnsupportedError('Demo history is read-only.');
  const DemoTestHistoryRepository();

  static final referenceDate = DateTime(2026, 10, 1);

  @override
  Future<List<AlcoholTestResult>> getResults() async {
    const offsets = [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      8,
      10,
      12,
      15,
      20,
      25,
      30,
      35,
      40,
      45,
      50,
      60,
      70,
      80,
      90,
      100,
      110,
    ];
    const readings = [0.08, 0.12, 0.18, 0.24, 0.31, 0.38, 0.42, 0.51];
    const classifier = AlcoholClassificationService();
    return List.unmodifiable([
      for (var i = 0; i < offsets.length; i++)
        for (final type in TestType.values)
          AlcoholTestResult(
            testType: type,
            sensorReading: readings[(i * 2 + type.index) % readings.length],
            status: classifier.classify(
              readings[(i * 2 + type.index) % readings.length],
            ),
            timestamp: DateTime(
              2026,
              10,
              1 - offsets[i],
              9 + type.index * 6,
              15,
            ),
          ),
    ]);
  }
}
