import 'package:flutter/foundation.dart';

import '../../../data/models/topic.dart';
import '../../../data/models/topic_status.dart';
import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/models/weak_area.dart';
import '../../../data/repositories/progress_repository.dart';
import 'next_step.dart';

/// The three figures under "So far".
@immutable
class HomeStats {
  const HomeStats({
    required this.topicsStarted,
    required this.topicsTotal,
    this.vocabLevel,
    this.grammarGain,
  });

  /// Topics the learner has taken a check in.
  ///
  /// Started rather than finished, deliberately. A topic only reaches
  /// [TopicStatus.completed] when its post-check comes back with nothing
  /// weak, so a learner who has done a check, the lessons, the practice and
  /// a second check can still be looking at a zero — for their first week.
  /// The finished count belongs on Progress, where there is room to show
  /// both and say why one is smaller.
  final int topicsStarted;

  final int topicsTotal;

  /// Null until the first vocabulary check has been taken.
  final int? vocabLevel;

  /// Mean of post minus pre, in percentage points, over every grammar topic
  /// that has both. Null until a post-assessment has been taken — there is
  /// nothing to average yet, and a zero would read as "you did not improve".
  ///
  /// Grammar only, and the label says so. Vocabulary keeps its own before and
  /// after, but its "before" is the level check — one question per area —
  /// against a final check that asks more. Folding two different instruments
  /// into one headline figure would put that noise on the front page.
  final int? grammarGain;
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

/// Home's three, mixed across sections.
///
/// Interleaved rather than concatenated, so a learner working in both
/// sections sees both. Starting with whichever they touched last keeps the
/// top of the list where their attention already is.
List<WeakArea> _weakAreas({
  required List<Topic> topics,
  required List<TopicProgress> progress,
  required VocabCourse course,
  required VocabPlan? plan,
  required List<VocabChunk> planChunks,
  required bool vocabularyFirst,
}) {
  final grammar = grammarWeakAreas(topics, progress);
  final vocabulary = vocabularyWeakAreas(
    course: course,
    plan: plan,
    planChunks: planChunks,
  );

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

  final touched = {for (final p in progress) p.topicId};

  return HomeStats(
    topicsStarted: topics.where((t) => touched.contains(t.id)).length,
    topicsTotal: topics.length,
    vocabLevel: plan?.level,
    grammarGain: gains.isEmpty
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
