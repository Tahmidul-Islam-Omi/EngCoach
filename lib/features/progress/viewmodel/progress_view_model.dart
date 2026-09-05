import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../vocabulary/viewmodel/vocab_plan_view_model.dart';
import '../model/progress_report.dart';

/// Everything the progress screen needs.
///
/// The same four sources Home joins, and deliberately the same providers:
/// [allTopicProgressProvider] is one query for every topic, so opening this
/// tab after Home costs nothing new — Riverpod is already holding the answer,
/// and the screens that write progress invalidate it for both.
final progressReportProvider = FutureProvider<ProgressReport>((ref) async {
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

  // Only needed to work out which word sets are still outstanding, which is
  // only a question when the plan names areas.
  final planChunks = switch (loaded.plan) {
    final p? when p.focusSubSkillIds.isNotEmpty => (await ref.watch(
      vocabLevelProvider(p.level).future,
    )).chunksFor(p.focusSubSkillIds),
    _ => const <VocabChunk>[],
  };

  return buildProgressReport(
    topics: loaded.topics,
    progress: loaded.progress,
    course: loaded.course,
    plan: loaded.plan,
    planChunks: planChunks,
  );
});
