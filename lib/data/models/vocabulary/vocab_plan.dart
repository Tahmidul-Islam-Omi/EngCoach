import 'package:flutter/foundation.dart';

import 'vocab_ladder.dart';
import 'vocab_result.dart';

/// What a learner has to study, how far through it they are, and what the
/// checks either side of it found.
///
/// Read off the check's profile once and then owned separately, because the
/// two answer different questions. The profile is a record of one run; the
/// plan is a piece of work in progress, and it outlives the check that
/// produced it.
@immutable
class VocabPlan {
  const VocabPlan({
    required this.level,
    required this.focusSubSkillIds,
    this.completedChunkIds = const [],
    this.before = const [],
    this.after,
    this.updatedAt,
  });

  /// Reads a finished check.
  factory VocabPlan.fromProfile(VocabProfile profile) => VocabPlan(
    level: profile.level,
    focusSubSkillIds: List.unmodifiable(profile.focusSubSkillIds),
    before: List.unmodifiable(profile.subSkills),
  );

  /// The rung the ladder settled on. Everything is taught at this level.
  final int level;

  /// The areas to teach, in authored order — which is teaching order.
  final List<String> focusSubSkillIds;

  /// Sets finished, by chunk id rather than subskill: a level may one day
  /// teach an area across more than one set.
  final List<String> completedChunkIds;

  /// Per-area scores from the first check, kept so the final check has
  /// something to be set against. Never overwritten — a learner's starting
  /// point does not change when they improve.
  final List<VocabSubSkillScore> before;

  /// Per-area scores from the most recent final check. Null until one is
  /// taken.
  final List<VocabSubSkillScore>? after;

  /// When the stored plan was last written.
  ///
  /// Read from Firestore, never written by the model: the repository stamps
  /// it, so a plan built in memory carries null until it has been saved and
  /// read back. Home compares it against a topic's `updatedAt` to decide
  /// which section the learner touched last.
  final DateTime? updatedAt;

  bool isDone(String chunkId) => completedChunkIds.contains(chunkId);

  bool get isEmpty => focusSubSkillIds.isEmpty;

  /// Every area the plan named has been practised, so the final check is the
  /// next thing to do.
  bool readyForFinalCheck(Iterable<String> chunkIds) {
    final ids = chunkIds.toList();
    return ids.isNotEmpty && ids.every(isDone);
  }

  VocabSubSkillScore? beforeFor(String subSkillId) =>
      before.where((s) => s.subSkillId == subSkillId).firstOrNull;

  VocabSubSkillScore? afterFor(String subSkillId) =>
      after?.where((s) => s.subSkillId == subSkillId).firstOrNull;

  VocabPlan withChunkDone(String chunkId) => isDone(chunkId)
      ? this
      : copyWith(
          completedChunkIds: List.unmodifiable([...completedChunkIds, chunkId]),
        );

  /// What a final check changes about the plan.
  ///
  /// The focus list is replaced rather than merged: the plan is meant to say
  /// what this learner still needs, and one built from a measurement six word
  /// sets ago no longer does. Completions clear with it — they were earned
  /// against the previous round, and leaving them would mark the new plan
  /// finished before it was started, re-offering the final check the moment
  /// it ended.
  VocabPlan withFinalCheck({
    required List<VocabSubSkillScore> after,
    required List<String> stillWeak,
  }) => VocabPlan(
    level: level,
    focusSubSkillIds: List.unmodifiable(stillWeak),
    completedChunkIds: const [],
    before: before,
    after: List.unmodifiable(after),
  );

  VocabPlan copyWith({
    int? level,
    List<String>? focusSubSkillIds,
    List<String>? completedChunkIds,
    List<VocabSubSkillScore>? before,
    List<VocabSubSkillScore>? after,
  }) => VocabPlan(
    level: level ?? this.level,
    focusSubSkillIds: focusSubSkillIds ?? this.focusSubSkillIds,
    completedChunkIds: completedChunkIds ?? this.completedChunkIds,
    before: before ?? this.before,
    after: after ?? this.after,
    updatedAt: updatedAt,
  );
}
