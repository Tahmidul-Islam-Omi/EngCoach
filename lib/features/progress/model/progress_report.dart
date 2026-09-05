import 'package:flutter/foundation.dart';

import '../../../data/models/topic.dart';
import '../../../data/models/topic_status.dart';
import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/models/weak_area.dart';
import '../../../data/repositories/progress_repository.dart';

/// One grammar topic's measured history.
@immutable
class TopicReport {
  const TopicReport({
    required this.topicId,
    required this.title,
    required this.status,
    required this.partsTotal,
    required this.partsWeak,
    this.before,
    this.after,
  });

  final String topicId;
  final String title;
  final TopicStatus status;

  /// How many parts the topic has, and how many of them are still both
  /// flagged and unpractised.
  final int partsTotal;
  final int partsWeak;

  /// First check. Null only if a topic document exists without one, which
  /// means practice was recorded before any check — possible offline.
  final int? before;

  /// Most recent second check. Null until one is taken.
  final int? after;

  /// Points gained, or null while there is nothing to compare against.
  int? get gain => (before == null || after == null) ? null : after! - before!;

  /// The most recent measurement, which is what the list sorts on.
  int get latest => after ?? before ?? 0;

  bool get measured => before != null;
}

/// One area's before and after, in raw counts.
///
/// Counts rather than percentages, deliberately. The "before" is the level
/// check, which asks a single question per area — rendering 0/1 as 0% and
/// 1/1 as 100% makes one question look like a measurement.
@immutable
class VocabAreaReport {
  const VocabAreaReport({
    required this.title,
    required this.beforeCorrect,
    required this.beforeTotal,
    this.afterCorrect,
    this.afterTotal,
  });

  final String title;
  final int beforeCorrect;
  final int beforeTotal;
  final int? afterCorrect;
  final int? afterTotal;

  bool get hasAfter => afterCorrect != null && afterTotal != null;
}

/// The vocabulary section's measured history.
@immutable
class VocabularyReport {
  const VocabularyReport({
    required this.level,
    required this.topLevel,
    required this.cleared,
    required this.areas,
  });

  final int level;
  final int topLevel;

  /// Every area the plan named has been proved, so the rung is behind them.
  final bool cleared;

  /// In the course's authored order, which is the order every other screen
  /// shows them in.
  final List<VocabAreaReport> areas;
}

/// One check the learner sat, for the dated list.
@immutable
class CheckEvent {
  const CheckEvent({
    required this.takenAt,
    required this.title,
    required this.detail,
  });

  final DateTime takenAt;
  final String title;
  final String detail;
}

/// Everything the progress screen draws.
@immutable
class ProgressReport {
  const ProgressReport({
    required this.topics,
    required this.notStarted,
    required this.weakAreas,
    required this.checks,
    this.overallBefore,
    this.overallAfter,
    this.reCheckedCount = 0,
    this.vocabulary,
  });

  /// Measured topics, weakest first.
  final List<TopicReport> topics;

  /// Topics never checked, in authored order.
  final List<Topic> notStarted;

  /// Every outstanding area, uncapped — this screen is the profile, not a
  /// plan for today.
  final List<WeakArea> weakAreas;

  /// Newest first.
  final List<CheckEvent> checks;

  /// The mean of each re-checked topic's first and second check.
  ///
  /// A mean of topic percentages rather than a pool of raw questions, so it
  /// agrees with the figure Home already shows: pooling would let a topic
  /// with more questions weigh more, and the two screens would then disagree
  /// about the same learner.
  final int? overallBefore;
  final int? overallAfter;
  final int reCheckedCount;

  final VocabularyReport? vocabulary;

  /// Whether there is a before and after to show at all.
  bool get hasEvidence => overallBefore != null && overallAfter != null;
}

/// Assembles the report from content and progress.
///
/// Pure, so every state tests without Firestore or a widget tree.
ProgressReport buildProgressReport({
  required List<Topic> topics,
  required List<TopicProgress> progress,
  required VocabCourse course,
  required VocabPlan? plan,
  required List<VocabChunk> planChunks,
}) {
  final byId = {for (final p in progress) p.topicId: p};

  // Paired with the authored index so ties can keep content order. Dart's
  // List.sort is not stable, so without the tiebreak two topics on the same
  // score could swap places between two builds of identical data.
  final ranked =
      <(int, TopicReport)>[
        for (final (i, topic) in topics.indexed)
          if (byId[topic.id] case final p?)
            (
              i,
              TopicReport(
                topicId: topic.id,
                title: topic.title,
                status: p.status,
                partsTotal: topic.subSkills.length,
                partsWeak: p.weakSubSkills.where((id) => !p.isDone(id)).length,
                before: p.preAssessment?.percent,
                after: p.postAssessment?.percent,
              ),
            ),
      ]..sort((a, b) {
        // Weakest first, so what needs work is at the top rather than
        // wherever the content author happened to put it.
        final byScore = a.$2.latest.compareTo(b.$2.latest);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });

  final measured = [for (final (_, report) in ranked) report];

  final gains = [
    for (final t in measured)
      if (t.before case final before?)
        if (t.after case final after?) (before: before, after: after),
  ];

  return ProgressReport(
    topics: measured,
    notStarted: [
      for (final topic in topics)
        if (!byId.containsKey(topic.id)) topic,
    ],
    weakAreas: [
      ...grammarWeakAreas(topics, progress),
      ...vocabularyWeakAreas(
        course: course,
        plan: plan,
        planChunks: planChunks,
      ),
    ],
    checks: _checks(topics, progress, plan),
    overallBefore: gains.isEmpty ? null : _mean(gains.map((g) => g.before)),
    overallAfter: gains.isEmpty ? null : _mean(gains.map((g) => g.after)),
    reCheckedCount: gains.length,
    vocabulary: _vocabulary(course, plan, planChunks),
  );
}

int _mean(Iterable<int> values) {
  final list = values.toList();
  return (list.reduce((a, b) => a + b) / list.length).round();
}

VocabularyReport? _vocabulary(
  VocabCourse course,
  VocabPlan? plan,
  List<VocabChunk> planChunks,
) {
  if (plan == null) return null;

  return VocabularyReport(
    level: plan.level,
    topLevel: course.ladder.topLevel,
    // Nothing left in the plan to teach, and a final check has been sat.
    cleared: plan.after != null && plan.focusSubSkillIds.isEmpty,
    areas: [
      // Driven by the course, so the authored order holds and an area
      // dropped from the content stops being reported.
      for (final subSkill in course.subSkills)
        if (plan.beforeFor(subSkill.id) case final before?)
          VocabAreaReport(
            title: subSkill.title,
            beforeCorrect: before.correct,
            beforeTotal: before.total,
            afterCorrect: plan.afterFor(subSkill.id)?.correct,
            afterTotal: plan.afterFor(subSkill.id)?.total,
          ),
    ],
  );
}

/// Every check the learner sat, newest first.
///
/// Grammar carries a `takenAt` on each stored snapshot, so both of a topic's
/// checks are datable. Vocabulary stores one `updatedAt` for the whole
/// section — last write wins — so it contributes a single entry describing
/// where it stands, not a history. Dating each vocabulary check would mean
/// storing a timestamp per check, which nothing writes today.
List<CheckEvent> _checks(
  List<Topic> topics,
  List<TopicProgress> progress,
  VocabPlan? plan,
) {
  final byId = {for (final p in progress) p.topicId: p};

  final events = <CheckEvent>[
    for (final topic in topics)
      if (byId[topic.id] case final p?) ...[
        if (p.preAssessment case final pre?)
          CheckEvent(
            takenAt: pre.takenAt,
            title: '${topic.title} — first check',
            detail: '${pre.percent}%, your starting point',
          ),
        if (p.postAssessment case final post?)
          CheckEvent(
            takenAt: post.takenAt,
            title: '${topic.title} — second check',
            detail: switch (post.percent - (p.preAssessment?.percent ?? 0)) {
              _ when p.preAssessment == null => '${post.percent}%',
              > 0 =>
                '${post.percent}%, up '
                    '${post.percent - p.preAssessment!.percent} points',
              0 => '${post.percent}%, no change',
              final down => '${post.percent}%, down ${-down} points',
            },
          ),
      ],
    if (plan?.updatedAt case final at?)
      CheckEvent(
        takenAt: at,
        title: plan!.after == null
            ? 'Vocabulary — level check'
            : 'Vocabulary Level ${plan.level} — final check',
        detail: plan.after == null
            ? 'Placed at Level ${plan.level}'
            : plan.focusSubSkillIds.isEmpty
            ? 'Level cleared'
            : '${plan.focusSubSkillIds.length} areas still to work on',
      ),
  ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));

  return events;
}
