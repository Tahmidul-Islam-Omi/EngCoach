import 'package:flutter/foundation.dart';

import '../../app/router.dart';
import '../repositories/progress_repository.dart';
import 'topic.dart';
import 'vocabulary/vocab_chunk.dart';
import 'vocabulary/vocab_course.dart';
import 'vocabulary/vocab_plan.dart';

/// One area the learner's own checks flagged and they have not practised yet.
///
/// Two screens need these: Home shows three as a plan for today, Progress
/// shows all of them as the profile. They are built here so a change to what
/// counts as outstanding lands on both at once.
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

  /// The lesson that teaches it. A weakness the learner cannot be sent
  /// straight at is not worth showing.
  final String route;
}

/// Every grammar area a check flagged that has not been practised since.
///
/// Walks the content rather than stored progress, so an id renamed out of the
/// content drops out instead of pointing at a lesson that no longer exists —
/// the same reason [Topic.subSkillsNamed] is driven that way.
List<WeakArea> grammarWeakAreas(
  List<Topic> topics,
  List<TopicProgress> progress,
) {
  final byId = {for (final p in progress) p.topicId: p};

  return [
    for (final topic in topics)
      if (byId[topic.id] case final p?)
        for (final id in p.weakSubSkills)
          if (!p.isDone(id))
            WeakArea(
              title: _titleOf(topic, id),
              context: topic.title,
              route: Routes.lesson(topic.id, id),
            ),
  ];
}

/// Every vocabulary area in the plan whose word set is still outstanding.
List<WeakArea> vocabularyWeakAreas({
  required VocabCourse course,
  required VocabPlan? plan,
  required List<VocabChunk> planChunks,
}) {
  if (plan == null) return const [];

  return [
    for (final id in plan.focusSubSkillIds)
      // The set that teaches this area, if it is still outstanding. An area
      // with no set left is not a weakness the learner can act on.
      if (planChunks
              .where((c) => c.subSkillId == id && !plan.isDone(c.id))
              .firstOrNull
          case final chunk?)
        WeakArea(
          title: _courseTitleOf(course, id),
          context: 'Vocabulary Level ${plan.level}',
          route: Routes.vocabularyChunk(chunk.id),
        ),
  ];
}

String _titleOf(Topic topic, String subSkillId) =>
    topic.subSkills
        .where((s) => s.id == subSkillId)
        .map((s) => s.title)
        .firstOrNull ??
    subSkillId;

String _courseTitleOf(VocabCourse course, String subSkillId) =>
    course.subSkills
        .where((s) => s.id == subSkillId)
        .map((s) => s.title)
        .firstOrNull ??
    subSkillId;
