import 'package:flutter/material.dart';

import '../services/completed_test_save.dart';

class TestSaveStatus extends StatelessWidget {
  const TestSaveStatus({super.key, required this.save});
  final CompletedTestSave save;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: save,
    builder: (context, _) => Column(
      children: [
        Text(switch (save.state) {
          TestSaveState.idle => 'Result ready to save.',
          TestSaveState.saving => 'Saving test result...',
          TestSaveState.saved => 'Test result saved.',
          TestSaveState.failed =>
            'Unable to confirm saving. Check your connection and retry.',
        }),
        if (save.state == TestSaveState.saving) const LinearProgressIndicator(),
        if (save.state == TestSaveState.failed)
          TextButton(onPressed: save.save, child: const Text('RETRY SAVE')),
      ],
    ),
  );
}
