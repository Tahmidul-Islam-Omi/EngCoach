import 'package:flutter/foundation.dart';

import 'vocab_ladder.dart';

/// What a learner has to study, and how far through it they are.
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
  });

  /// Reads a finished check.
  factory VocabPlan.fromProfile(VocabProfile profile) => VocabPlan(
    level: profile.level,
    focusSubSkillIds: List.unmodifiable(profile.focusSubSkillIds),
  );

  /// The rung the ladder settled on. Everything is taught at this level.
  final int level;

  /// The areas to teach, in authored order — which is teaching order.
  final List<String> focusSubSkillIds;

  /// Chunks finished, by chunk id rather than subskill: a level may one day
  /// teach an area across more than one chunk.
  final List<String> completedChunkIds;

  bool isDone(String chunkId) => completedChunkIds.contains(chunkId);

  bool get isEmpty => focusSubSkillIds.isEmpty;

  VocabPlan withChunkDone(String chunkId) => isDone(chunkId)
      ? this
      : VocabPlan(
          level: level,
          focusSubSkillIds: focusSubSkillIds,
          completedChunkIds: List.unmodifiable([...completedChunkIds, chunkId]),
        );
}
