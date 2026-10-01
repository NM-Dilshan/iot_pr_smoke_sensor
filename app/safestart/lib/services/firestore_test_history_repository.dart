import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alcohol_test_result.dart';
import 'test_history_repository.dart';
import 'firestore_codec.dart';

class FirestoreTestHistoryRepository implements TestHistoryRepository {
  FirestoreTestHistoryRepository(FirebaseFirestore firestore, String uid)
    : _tests = firestore.collection('users').doc(uid).collection('tests');
  final CollectionReference<Map<String, dynamic>> _tests;
  @override
  Future<List<AlcoholTestResult>> getResults() async {
    final snapshot = await _tests
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    // Fail visibly rather than silently reporting inaccurate analytics from corrupt records.
    final results = snapshot.docs
        .map((doc) => FirestoreCodec.result(doc.data()))
        .toList();
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  @override
  Future<void> saveResult(String id, AlcoholTestResult result) async {
    final data = FirestoreCodec.resultData(result);
    final document = _tests.doc(id);
    // Stable ID and create-once transaction make retries idempotent, including
    // retry after an uncertain network outcome. No offline queued writes.
    await _tests.firestore
        .runTransaction((transaction) async {
          final existing = await transaction.get(document);
          if (!existing.exists) transaction.set(document, data);
        })
        .timeout(const Duration(seconds: 20));
  }
}
