import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/learner_snapshot.dart';
import '../model/progress_report.dart';

/// What the progress screen draws.
///
/// Reads the same snapshot Home does, so opening this tab after Home costs
/// no further reads.
final progressReportProvider = FutureProvider<ProgressReport>((ref) async {
  final s = await ref.watch(learnerSnapshotProvider.future);

  return buildProgressReport(
    topics: s.topics,
    progress: s.progress,
    course: s.course,
    plan: s.plan,
    planChunks: s.planChunks,
  );
});
