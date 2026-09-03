import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vocabulary/vocab_ladder.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';

/// The learner's current vocabulary plan.
///
/// In memory for now: the plan is written when the check settles and read by
/// the path and the word cards, all within one session. Step 6 replaces the
/// store with Firestore, at which point this becomes a thin front for the
/// progress repository — the screens above it do not change, which is why
/// they are written against this rather than against the check's own state.
///
/// Null means the check has not been taken on this device yet.
class VocabPlanViewModel extends Notifier<VocabPlan?> {
  @override
  VocabPlan? build() => null;

  /// Replaces any earlier plan. A second check is a new diagnosis, not an
  /// amendment to the old one — the level may have moved, and completed
  /// chunks from a different level would be meaningless against it.
  void adopt(VocabProfile profile) => state = VocabPlan.fromProfile(profile);

  void markChunkComplete(String chunkId) {
    final plan = state;
    if (plan == null) return;

    state = plan.withChunkDone(chunkId);
  }
}

final vocabPlanProvider = NotifierProvider<VocabPlanViewModel, VocabPlan?>(
  VocabPlanViewModel.new,
);
