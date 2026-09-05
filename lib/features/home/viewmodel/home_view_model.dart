import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../vocabulary/viewmodel/vocab_plan_view_model.dart';
import '../model/home_state.dart';

/// Everything the home screen needs, joined from both sections.
///
/// A plain [FutureProvider] rather than a notifier: Home writes nothing. It
/// refreshes by invalidating the providers it reads — and because it watches
/// [vocabPlanProvider], vocabulary work already reflects here without Home
/// asking.
///
/// The four reads are started together and awaited afterwards, so the screen
/// waits for the slowest rather than the sum of all four.
final homeStateProvider = FutureProvider<HomeState>((ref) async {
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
  // the screen never draws.
  final planChunks = switch (loaded.plan) {
    final p? when p.focusSubSkillIds.isNotEmpty => (await ref.watch(
      vocabLevelProvider(p.level).future,
    )).chunksFor(p.focusSubSkillIds),
    _ => const <VocabChunk>[],
  };

  return buildHomeState(
    topics: loaded.topics,
    progress: loaded.progress,
    course: loaded.course,
    plan: loaded.plan,
    planChunks: planChunks,
  );
});
