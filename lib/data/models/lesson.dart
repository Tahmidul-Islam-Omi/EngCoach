import 'package:json_annotation/json_annotation.dart';

import 'lesson_block.dart';
import 'question.dart';

// Content is read-only in the app: authored in JSON, parsed once, never
// written back. `createToJson: false` keeps the generator from demanding a
// toJson for the sealed LessonBlock hierarchy.

part 'lesson.g.dart';

/// One lesson, targeted at a single sub-skill.
///
/// A learner only sees the lessons for sub-skills their pre-assessment
/// flagged as weak (SPEC §4.5) — the rest are skipped.
@JsonSerializable(createToJson: false)
class Lesson {
  const Lesson({
    required this.id,
    required this.subSkillId,
    required this.title,
    required this.blocks,
    required this.practice,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);

  final String id;
  final String subSkillId;
  final String title;

  /// Rendered in order. Sealed, so the renderer must handle every kind.
  @JsonKey(fromJson: _blocksFromJson)
  final List<LessonBlock> blocks;

  /// Instructional practice — unlike an assessment, these show the answer
  /// and an explanation immediately (SPEC §6, Phase 2).
  final List<Question> practice;

  static List<LessonBlock> _blocksFromJson(List<dynamic> json) => json
      .map((b) => LessonBlock.fromJson(b as Map<String, dynamic>))
      .toList();
}
