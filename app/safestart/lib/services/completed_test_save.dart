import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/alcohol_test_result.dart';
import 'test_history_repository.dart';

enum TestSaveState { idle, saving, saved, failed }

/// One controller per completed sampling run, shared across result route visits.
class CompletedTestSave extends ChangeNotifier {
  CompletedTestSave(this.repository, this.result, {this.onSaved})
    : id = List.generate(
        20,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
  final TestHistoryRepository repository;
  final AlcoholTestResult result;
  final String id;
  final VoidCallback? onSaved;
  TestSaveState state = TestSaveState.idle;
  Future<void> save() async {
    if (state == TestSaveState.saving || state == TestSaveState.saved) return;
    state = TestSaveState.saving;
    notifyListeners();
    try {
      await repository.saveResult(id, result);
      state = TestSaveState.saved;
      onSaved?.call();
    } catch (_) {
      state = TestSaveState.failed;
    }
    notifyListeners();
  }
}
