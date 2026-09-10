import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/learner_snapshot.dart';
import '../model/home_state.dart';

/// What the home screen draws.
///
/// The reading is [learnerSnapshotProvider]'s job; this only turns the
/// snapshot into the day's plan.
final homeStateProvider = FutureProvider<HomeState>((ref) async {
  final s = await ref.watch(learnerSnapshotProvider.future);

  return buildHomeState(
    topics: s.topics,
    progress: s.progress,
    course: s.course,
    plan: s.plan,
    planChunks: s.planChunks,
  );
});
