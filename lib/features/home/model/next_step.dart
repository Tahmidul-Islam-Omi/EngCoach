import 'package:flutter/foundation.dart';

import '../../../data/models/topic.dart';
import '../../../data/models/topic_status.dart';
import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/repositories/progress_repository.dart';

/// The one thing Home puts at the top of the screen.
///
/// Sealed so the switch that draws it is exhaustive: a state with no next
/// action is a dead end, and the compiler is what stops one being added.
@immutable
sealed class NextStep {
  const NextStep();

  /// Whether the learner has work already underway.
  ///
  /// Home hides the finished-topics list and the "start something new" row
  /// while this is true: when there is something to finish, everything else
  /// is noise; when there isn't, they are the way forward.
  bool get isWorkInProgress => switch (this) {
    ContinueTopic() ||
    StartTopicLearning() ||
    TakeTopicPostCheck() ||
    ContinueVocabulary() ||
    TakeVocabularyFinalCheck() => true,
    StartFirstTopic() ||
    StartNewTopic() ||
    CheckNextVocabularyLevel() ||
    StartVocabulary() ||
    NothingLeft() => false,
  };
}

/// Nothing has been started, in either section.
final class StartFirstTopic extends NextStep {
  const StartFirstTopic();
}

/// A topic is part-taught: some of its weak areas are practised, some aren't.
final class ContinueTopic extends NextStep {
  const ContinueTopic({
    required this.topicId,
    required this.title,
    required this.done,
    required this.total,
    required this.nextArea,
  });

  final String topicId;
  final String title;
  final int done;
  final int total;

  /// The authored title of the next unpractised area, so the card can name
  /// what the learner is about to do rather than only where they are.
  final String nextArea;
}

/// The check was taken and then abandoned. The expensive part is already paid
/// for, so the step is to start the lessons it produced.
final class StartTopicLearning extends NextStep {
  const StartTopicLearning({required this.topicId, required this.title});

  final String topicId;
  final String title;
}

/// Every area is practised. This is where improvement gets proved.
final class TakeTopicPostCheck extends NextStep {
  const TakeTopicPostCheck({required this.topicId, required this.title});

  final String topicId;
  final String title;
}

/// Nothing in flight, but a topic has never been opened.
final class StartNewTopic extends NextStep {
  const StartNewTopic({required this.topicId, required this.title});

  final String topicId;
  final String title;
}

/// Word sets are left in the current vocabulary plan.
final class ContinueVocabulary extends NextStep {
  const ContinueVocabulary({
    required this.level,
    required this.done,
    required this.total,
  });

  final int level;
  final int done;
  final int total;
}

/// Every set in the plan is finished.
final class TakeVocabularyFinalCheck extends NextStep {
  const TakeVocabularyFinalCheck(this.level);

  final int level;
}

/// The level was cleared and there is a rung above it.
final class CheckNextVocabularyLevel extends NextStep {
  const CheckNextVocabularyLevel(this.level);

  /// The level about to be checked, not the one just cleared.
  final int level;
}

/// Grammar has nothing pending and vocabulary has never been checked.
final class StartVocabulary extends NextStep {
  const StartVocabulary();
}

/// Every topic is finished and the top vocabulary level is cleared.
final class NothingLeft extends NextStep {
  const NothingLeft();
}

// ---------------------------------------------------------------- the rule

/// The newest of a set of timestamps, or null if there are none.
///
/// A missing timestamp sorts as "long ago": progress written before the field
/// existed should lose to progress written after it, not win by accident.
@visibleForTesting
DateTime? latestOf(Iterable<DateTime?> stamps) {
  DateTime? latest;
  for (final s in stamps) {
    if (s != null && (latest == null || s.isAfter(latest))) latest = s;
  }
  return latest;
}

/// Whether vocabulary is the section the learner touched most recently.
///
/// Grammar keeps the tie and the unstamped case, because its data is older:
/// someone upgrading from a build that never wrote timestamps has grammar
/// progress and at most one vocabulary plan, and flipping them on a null
/// would send them somewhere they have not been in weeks.
bool vocabularyTouchedLast({
  required List<TopicProgress> progress,
  required VocabPlan? plan,
}) {
  final vocabularyAt = plan?.updatedAt;
  if (vocabularyAt == null) return false;

  final grammarAt = latestOf(progress.map((p) => p.updatedAt));
  return grammarAt == null || vocabularyAt.isAfter(grammarAt);
}

/// What Home should offer next.
///
/// Each section decides its own next step from its own data, and the section
/// the learner touched most recently wins. Only when neither section has work
/// in flight does this fall through to starting something new — a learner
/// halfway through a topic should never be told to begin a different one.
///
/// Pure: every input is already loaded, so all of it tests without Firestore.
NextStep nextStep({
  required List<Topic> topics,
  required List<TopicProgress> progress,
  required VocabPlan? plan,
  required List<VocabChunk> planChunks,
  required int topLevel,
}) {
  final grammar = _grammarStep(topics, progress);
  final vocabulary = _vocabularyStep(plan, planChunks, topLevel);

  if (grammar != null && vocabulary != null) {
    return vocabularyTouchedLast(progress: progress, plan: plan)
        ? vocabulary
        : grammar;
  }

  if (grammar != null) return grammar;
  if (vocabulary != null) return vocabulary;

  // Nothing is in flight. Offer something new, preferring an untouched topic
  // over a vocabulary check the learner has already been through.
  final untouched = _firstUntouched(topics, progress);
  if (untouched != null) {
    return progress.isEmpty && plan == null
        ? const StartFirstTopic()
        : StartNewTopic(topicId: untouched.id, title: untouched.title);
  }

  if (plan == null) return const StartVocabulary();
  return const NothingLeft();
}

/// Grammar's own next step, or null if no topic is in flight.
///
/// Topics are walked in authored order, so with no timestamps to separate two
/// half-finished topics the answer is at least stable rather than arbitrary.
NextStep? _grammarStep(List<Topic> topics, List<TopicProgress> progress) {
  final byId = {for (final p in progress) p.topicId: p};

  // Ordered by how far along the topic is, most advanced first: a learner
  // with one topic ready for its post-check and another barely started
  // should be pointed at the one they can finish.
  NextStep? readyToProve;
  NextStep? partTaught;
  NextStep? checkedOnly;

  for (final topic in topics) {
    final p = byId[topic.id];
    if (p == null) continue;
    if (p.status == TopicStatus.completed || p.status == TopicStatus.mastered) {
      continue;
    }

    final plan = p.weakSubSkills;
    // A check that found nothing weak leaves nothing to teach; the topic is
    // already at completed and was skipped above.
    if (plan.isEmpty) continue;

    final done = p.doneCount;
    if (done >= plan.length) {
      readyToProve ??= TakeTopicPostCheck(
        topicId: topic.id,
        title: topic.title,
      );
      continue;
    }

    if (done > 0) {
      final nextId = plan.firstWhere((id) => !p.isDone(id));
      partTaught ??= ContinueTopic(
        topicId: topic.id,
        title: topic.title,
        done: done,
        total: plan.length,
        nextArea: _areaTitle(topic, nextId),
      );
      continue;
    }

    checkedOnly ??= StartTopicLearning(topicId: topic.id, title: topic.title);
  }

  return readyToProve ?? partTaught ?? checkedOnly;
}

/// Vocabulary's own next step, or null if there is nothing in flight.
NextStep? _vocabularyStep(
  VocabPlan? plan,
  List<VocabChunk> planChunks,
  int topLevel,
) {
  if (plan == null) return null;

  if (planChunks.isNotEmpty) {
    final done = planChunks.where((c) => plan.isDone(c.id)).length;
    if (done < planChunks.length) {
      return ContinueVocabulary(
        level: plan.level,
        done: done,
        total: planChunks.length,
      );
    }
    return TakeVocabularyFinalCheck(plan.level);
  }

  // No sets to teach. Either the final check cleared the level, or the first
  // check found nothing weak at it — both mean the rung above is the next
  // thing worth measuring.
  if (plan.level < topLevel) return CheckNextVocabularyLevel(plan.level + 1);
  return null;
}

Topic? _firstUntouched(List<Topic> topics, List<TopicProgress> progress) {
  final touched = {for (final p in progress) p.topicId};
  for (final topic in topics) {
    if (!touched.contains(topic.id)) return topic;
  }
  return null;
}

String _areaTitle(Topic topic, String subSkillId) =>
    topic.subSkills
        .where((s) => s.id == subSkillId)
        .map((s) => s.title)
        .firstOrNull ??
    subSkillId;
