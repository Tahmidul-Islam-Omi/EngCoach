import 'package:json_annotation/json_annotation.dart';

import 'vocab_chunk.dart';
import 'vocab_question.dart';

part 'vocab_level.g.dart';

/// One subskill's questions at one level.
///
/// Carries no title: the six subskills are the same at every level, so their
/// names live once in `course.json`. Repeating them per level would be four
/// places for the same word to drift.
@JsonSerializable(createToJson: false)
class LevelSubSkill {
  const LevelSubSkill({
    required this.id,
    required this.preAssessmentBank,
    required this.postAssessmentBank,
  });

  factory LevelSubSkill.fromJson(Map<String, dynamic> json) =>
      _$LevelSubSkillFromJson(json);

  final String id;

  /// Deliberately larger than the one question a level check draws. The
  /// spare questions are what the borderline probe spends (SPEC §3) and what
  /// makes a retake a different paper.
  final List<VocabQuestion> preAssessmentBank;

  /// Different words and sentences, same subskill and types (SPEC §15).
  final List<VocabQuestion> postAssessmentBank;
}

/// A rung of the ladder: how hard the words are, and what is taught there.
@JsonSerializable(createToJson: false)
class VocabLevel {
  const VocabLevel({
    required this.level,
    required this.title,
    required this.summary,
    required this.subSkills,
    required this.chunks,
  });

  factory VocabLevel.fromJson(Map<String, dynamic> json) =>
      _$VocabLevelFromJson(json);

  /// 1-based. Nothing in the code knows how many levels exist — that is
  /// `ladder.topLevel`, so Level 5 is a content change (SPEC §1).
  final int level;

  /// Learner-facing, e.g. "Intermediate". Never "Medium" (SPEC §1).
  final String title;

  final String summary;
  final List<LevelSubSkill> subSkills;
  final List<VocabChunk> chunks;

  LevelSubSkill subSkill(String id) => subSkills.firstWhere((s) => s.id == id);

  /// The chunks teaching [subSkillIds], in authored order.
  ///
  /// Driven by the level rather than by the given list, so an id left over in
  /// a learner's stored progress after a content edit simply drops out
  /// instead of pointing at a chunk that no longer exists.
  List<VocabChunk> chunksFor(Iterable<String> subSkillIds) {
    final wanted = subSkillIds.toSet();
    return [
      for (final c in chunks)
        if (wanted.contains(c.subSkillId)) c,
    ];
  }
}
