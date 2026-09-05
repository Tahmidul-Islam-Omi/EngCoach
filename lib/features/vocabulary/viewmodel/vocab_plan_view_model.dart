import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vocabulary/vocab_ladder.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/models/vocabulary/vocab_result.dart';
import '../../../data/repositories/vocab_progress_repository.dart';

/// The learner's vocabulary plan.
///
/// Async because it is read from Firestore on the way in: a synchronous null
/// would mean "no check taken yet" and "not loaded yet" at the same time, and
/// the plan screen would flash "take the check first" at a learner who has a
/// plan waiting.
///
/// Every write updates state first and persists afterwards. The learner has
/// already done the work; a slow connection must not hold the screen, and
/// Firestore queues the write offline.
class VocabPlanViewModel extends AsyncNotifier<VocabPlan?> {
  VocabProgressRepository get _repo =>
      ref.read(vocabProgressRepositoryProvider);

  @override
  Future<VocabPlan?> build() => _repo.plan();

  /// Replaces any earlier plan. A second check is a new diagnosis, not an
  /// amendment to the old one.
  Future<void> adopt(VocabProfile profile) async {
    // Let any in-flight read finish first. Without this, a learner who takes
    // the check before the stored plan has loaded would have the new plan
    // overwritten by the old one arriving a moment later.
    await _settled();

    final plan = VocabPlan.fromProfile(profile);
    state = AsyncData(plan);
    await _write(() => _repo.savePlan(plan));
  }

  Future<void> markChunkComplete(String chunkId) async {
    await _settled();

    final plan = state.value;
    if (plan == null) return;

    final next = plan.withChunkDone(chunkId);
    if (identical(next, plan)) return;

    state = AsyncData(next);
    await _write(() => _repo.markChunkComplete(chunkId));
  }

  /// Rewrites the plan around what the final check found.
  Future<void> recordFinalCheck({
    required List<VocabSubSkillScore> after,
    required List<String> stillWeak,
  }) async {
    await _settled();

    final plan = state.value;
    if (plan == null) return;

    final next = plan.withFinalCheck(after: after, stillWeak: stillWeak);
    state = AsyncData(next);
    await _write(() => _repo.savePlan(next));
  }

  /// Waits for the initial read, ignoring its failure — a plan that could not
  /// be loaded must not stop a new one being written over it.
  Future<void> _settled() async {
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      // Nothing useful to tell the learner: the plan is on screen either way,
      // and Firestore retries the write itself. Reported once Crashlytics is
      // in — one of four such gaps.
    }
  }
}

final vocabPlanProvider = AsyncNotifierProvider<VocabPlanViewModel, VocabPlan?>(
  VocabPlanViewModel.new,
);
