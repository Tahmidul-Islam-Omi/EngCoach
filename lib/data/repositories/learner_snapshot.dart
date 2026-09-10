import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/vocabulary/viewmodel/vocab_plan_view_model.dart';
import '../models/topic.dart';
import '../models/vocabulary/vocab_chunk.dart';
import '../models/vocabulary/vocab_course.dart';
import '../models/vocabulary/vocab_plan.dart';
import 'content_repository.dart';
import 'progress_repository.dart';
import 'vocabulary_repository.dart';

/// Both sections' content and progress, read together.
///
/// Home and Progress are the only screens that answer questions spanning
/// grammar and vocabulary at once, and they need exactly the same five
/// things to do it. A section added later that also reads across both gets
/// them from here rather than assembling its own join.
@immutable
class LearnerSnapshot {
  const LearnerSnapshot({
    required this.topics,
    required this.progress,
    required this.course,
    required this.plan,
    required this.planChunks,
  });

  final List<Topic> topics;
  final List<TopicProgress> progress;
  final VocabCourse course;

  /// Null until the first vocabulary check has been taken.
  final VocabPlan? plan;

  /// The word sets the plan still names. Empty when there is no plan, or
  /// when a cleared plan names no areas.
  final List<VocabChunk> planChunks;
}

/// Reads everything Home and Progress are built from.
///
/// A plain [FutureProvider] because neither screen writes: they refresh by
/// invalidating the providers underneath, and the screens that do write
/// invalidate those for them.
///
/// The four reads are started together and awaited afterwards, so a screen
/// waits for the slowest rather than the sum of all four.
///
/// This exists to remove a duplicated join, not to save reads: Riverpod
/// already cached the providers underneath, so Home and Progress shared one
/// read of each even when they assembled the join separately.
final learnerSnapshotProvider = FutureProvider<LearnerSnapshot>((ref) async {
  final topics = ref.watch(sectionTopicsProvider('grammar').future);
  final progress = ref.watch(allTopicProgressProvider.future);
  final course = ref.watch(vocabCourseProvider.future);
  final plan = ref.watch(vocabPlanProvider.future);

  final loaded = (
    topics: await topics,
    progress: await progress,
    course: await course,
    plan: await plan,
  );

  // The level's word sets, only when there is a plan that names areas.
  // Reading a level nobody is studying would cost a file parse for a list
  // no screen draws.
  final planChunks = switch (loaded.plan) {
    final p? when p.focusSubSkillIds.isNotEmpty => (await ref.watch(
      vocabLevelProvider(p.level).future,
    )).chunksFor(p.focusSubSkillIds),
    _ => const <VocabChunk>[],
  };

  return LearnerSnapshot(
    topics: loaded.topics,
    progress: loaded.progress,
    course: loaded.course,
    plan: loaded.plan,
    planChunks: planChunks,
  );
});
