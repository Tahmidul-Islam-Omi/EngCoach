import 'package:flutter/foundation.dart';

import '../../../app/router.dart';
import '../../../data/models/topic.dart';
import '../../../data/models/topic_status.dart';
import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/repositories/progress_repository.dart';
import 'next_step.dart';

/// One area the learner's own checks flagged and they have not practised yet.
@immutable
class WeakArea {
  const WeakArea({
    required this.title,
    required this.context,
    required this.route,
  });

  /// The authored sub-skill title, never an id.
  final String title;

  /// Where it came from — a topic name, or the vocabulary level.
  final String context;

  /// The lesson that teaches it. Home never shows a weakness it cannot
  /// send the learner straight at.
  final String route;
}

/// The three figures under "So far".
@immutable
class HomeStats {
  const HomeStats({
    required this.topicsDone,
    required this.topicsTotal,
    this.vocabLevel,
    this.averageGain,
  });

  final int topicsDone;
  final int topicsTotal;

  /// Null until the first vocabulary check has been taken.
  final int? vocabLevel;

  /// Mean of post minus pre, over every topic that has both. Null until a
  /// post-assessment has been taken — there is nothing to average yet, and a
  /// zero would read as "you did not improve".
  final int? averageGain;
}

/// Everything the home screen draws.
@immutable
class HomeState {
  const HomeState({
    required this.next,
    required this.weakAreas,
    required this.stats,
    this.alsoInProgress,
    this.finished = const [],
    this.untouched = const [],
  });

  /// The hero card. Always present — a home screen with no next action is a
  /// dead end.
  final NextStep next;

  /// The section that did not win the hero, when both had work. Drawn as a
  /// single row so the other half of the learner's work is still reachable
  /// without hunting for it.
  final NextStep? alsoInProgress;

  /// At most three, mixed across sections.
  final List<WeakArea> weakAreas;

  final HomeStats stats;

  /// Topics behind them. Only filled when nothing is in flight.
  final List<Topic> finished;

  /// Topics never opened. Only filled when nothing is in flight.
  final List<Topic> untouched;
}

/// How many weak areas the screen offers at once.
///
/// Three is the point where the list still reads as "today's work" rather
/// than a backlog. The learner's full profile lives on the topic screens.
const _weakAreaLimit = 3;

/// Assembles the screen from content and progress.
///
/// Pure, so every state tests without Firestore or a widget tree.
HomeState buildHomeState({
  required List<Topic> topics,
  required List<TopicProgress> progress,
  required VocabCourse course,
  required VocabPlan? plan,
  required List<VocabChunk> planChunks,
}) {
  final next = nextStep(
    topics: topics,
    progress: progress,
    plan: plan,
    planChunks: planChunks,
    topLevel: course.ladder.topLevel,
  );

  final vocabularyLast = vocabularyTouchedLast(progress: progress, plan: plan);
  final inFlight = next.isWorkInProgress;

  return HomeState(
    next: next,
    alsoInProgress: _alsoInProgress(
      next,
      topics,
      progress,
      plan,
      planChunks,
      course.ladder.topLevel,
    ),
    weakAreas: _weakAreas(
      topics: topics,
      progress: progress,
      course: course,
      plan: plan,
      planChunks: planChunks,
      vocabularyFirst: vocabularyLast,
    ),
    stats: _stats(topics: topics, progress: progress, plan: plan),
    finished: inFlight ? const [] : _byStatus(topics, progress, done: true),
    untouched: inFlight ? const [] : _untouched(topics, progress, next),
  );
}

/// The other section's step, when the hero took one of them.
///
/// Recomputed by asking each section on its own rather than by remembering
/// the loser: the two are independent, and one nullable answer each is
/// simpler to reason about than a pair threaded through the rule.
NextStep? _alsoInProgress(
  NextStep next,
  List<Topic> topics,
  List<TopicProgress> progress,
  VocabPlan? plan,
  List<VocabChunk> planChunks,
  int topLevel,
) {
  if (!next.isWorkInProgress) return null;

  final grammarWon = switch (next) {
    ContinueTopic() || StartTopicLearning() || TakeTopicPostCheck() => true,
    _ => false,
  };

  final other = grammarWon
      ? nextStep(
          topics: const [],
          progress: const [],
          plan: plan,
          planChunks: planChunks,
          topLevel: topLevel,
        )
      : nextStep(
          topics: topics,
          progress: progress,
          plan: null,
          planChunks: const [],
          topLevel: topLevel,
        );

  return other.isWorkInProgress ? other : null;
}

List<WeakArea> _weakAreas({
  required List<Topic> topics,
  required List<TopicProgress> progress,
  required VocabCourse course,
  required VocabPlan? plan,
  required List<VocabChunk> planChunks,
  required bool vocabularyFirst,
}) {
  final byId = {for (final p in progress) p.topicId: p};

  final grammar = <WeakArea>[
    for (final topic in topics)
      if (byId[topic.id] case final p?)
        for (final id in p.weakSubSkills)
          if (!p.isDone(id))
            WeakArea(
              title:
                  topic.subSkills
                      .where((s) => s.id == id)
                      .map((s) => s.title)
                      .firstOrNull ??
                  id,
              context: topic.title,
              route: Routes.lesson(topic.id, id),
            ),
  ];

  final vocabulary = <WeakArea>[
    if (plan != null)
      for (final id in plan.focusSubSkillIds)
        // The set that teaches this area, if it is still outstanding. An
        // area with no set left is not a weakness the learner can act on.
        if (planChunks
                .where((c) => c.subSkillId == id && !plan.isDone(c.id))
                .firstOrNull
            case final chunk?)
          WeakArea(
            title:
                course.subSkills
                    .where((s) => s.id == id)
                    .map((s) => s.title)
                    .firstOrNull ??
                id,
            context: 'Vocabulary Level ${plan.level}',
            route: Routes.vocabularyChunk(chunk.id),
          ),
  ];

  // Interleaved rather than concatenated, so a learner working in both
  // sections sees both. Starting with whichever they touched last keeps the
  // top of the list where their attention already is.
  final first = vocabularyFirst ? vocabulary : grammar;
  final second = vocabularyFirst ? grammar : vocabulary;

  final mixed = <WeakArea>[];
  for (var i = 0; mixed.length < _weakAreaLimit; i++) {
    if (i >= first.length && i >= second.length) break;
    if (i < first.length) mixed.add(first[i]);
    if (mixed.length < _weakAreaLimit && i < second.length) {
      mixed.add(second[i]);
    }
  }
  return mixed;
}

HomeStats _stats({
  required List<Topic> topics,
  required List<TopicProgress> progress,
  required VocabPlan? plan,
}) {
  final gains = <int>[
    for (final p in progress)
      if (p.preAssessment case final pre?)
        if (p.postAssessment case final post?) post.percent - pre.percent,
  ];

  return HomeStats(
    topicsDone: _byStatus(topics, progress, done: true).length,
    topicsTotal: topics.length,
    vocabLevel: plan?.level,
    averageGain: gains.isEmpty
        ? null
        : (gains.reduce((a, b) => a + b) / gains.length).round(),
  );
}

/// Topics that are finished, in authored order.
List<Topic> _byStatus(
  List<Topic> topics,
  List<TopicProgress> progress, {
  required bool done,
}) {
  final byId = {for (final p in progress) p.topicId: p};
  return [
    for (final topic in topics)
      if (byId[topic.id]?.status case final s?)
        if ((s == TopicStatus.completed || s == TopicStatus.mastered) == done)
          topic,
  ];
}

/// Topics never opened, minus the one the hero is already offering.
List<Topic> _untouched(
  List<Topic> topics,
  List<TopicProgress> progress,
  NextStep next,
) {
  final touched = {for (final p in progress) p.topicId};
  final offered = switch (next) {
    StartNewTopic(:final topicId) => topicId,
    _ => null,
  };
  return [
    for (final topic in topics)
      if (!touched.contains(topic.id) && topic.id != offered) topic,
  ];
}
