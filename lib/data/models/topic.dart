import 'package:json_annotation/json_annotation.dart';

import 'lesson.dart';
import 'question.dart';

// Content is read-only in the app: authored in JSON, parsed once, never
// written back. `createToJson: false` keeps the generator from demanding a
// toJson for the sealed LessonBlock hierarchy.

part 'topic.g.dart';

/// How a topic's diagnostic is assembled.
@JsonSerializable(createToJson: false)
class AssessmentConfig {
  const AssessmentConfig({
    required this.questionsPerSubSkill,
    required this.qualifyingScore,
  });

  factory AssessmentConfig.fromJson(Map<String, dynamic> json) =>
      _$AssessmentConfigFromJson(json);

  /// Drawn at random from each sub-skill's bank, so two learners rarely see
  /// the same check and nobody can memorise it.
  final int questionsPerSubSkill;

  /// Score needed to skip a sub-skill. Must be <= [questionsPerSubSkill],
  /// or nothing is ever skipped — the validator enforces this.
  final int qualifyingScore;
}

/// One unit a pre-assessment scores against — the granularity at which
/// EngCoach decides "you already know this" (SPEC §6).
@JsonSerializable(createToJson: false)
class SubSkill {
  const SubSkill({
    required this.id,
    required this.title,
    required this.preAssessmentBank,
    required this.postAssessmentBank,
  });

  factory SubSkill.fromJson(Map<String, dynamic> json) =>
      _$SubSkillFromJson(json);

  final String id;
  final String title;

  /// Options here carry no feedback — the first check shows nothing.
  final List<Question> preAssessmentBank;

  /// Different questions from [preAssessmentBank], covering the same rules
  /// in the same proportion, with feedback for the result screen.
  final List<Question> postAssessmentBank;
}

@JsonSerializable(createToJson: false)
class Topic {
  const Topic({
    required this.id,
    required this.section,
    required this.order,
    required this.title,
    required this.summary,
    required this.whyThisTopic,
    required this.assessmentConfig,
    required this.subSkills,
    required this.lessons,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);

  final String id;
  final String section;
  final int order;
  final String title;
  final String summary;

  /// Shown on the topic overview to explain why this is worth studying.
  final String whyThisTopic;

  final AssessmentConfig assessmentConfig;
  final List<SubSkill> subSkills;
  final List<Lesson> lessons;

  /// Total questions in a full pre-assessment.
  int get preAssessmentLength =>
      subSkills.length * assessmentConfig.questionsPerSubSkill;

  Lesson lessonFor(String subSkillId) =>
      lessons.firstWhere((l) => l.subSkillId == subSkillId);

  SubSkill subSkill(String id) => subSkills.firstWhere((s) => s.id == id);
}
