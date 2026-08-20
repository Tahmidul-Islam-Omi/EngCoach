import 'package:json_annotation/json_annotation.dart';

// Content is read-only in the app: authored in JSON, parsed once, never
// written back. `createToJson: false` keeps the generator from demanding a
// toJson for the sealed LessonBlock hierarchy.

part 'question.g.dart';

/// Authored explanation shown after a wrong (or right) answer.
///
/// Never generated at runtime — SPEC §4.1 and §12 require human-authored
/// curriculum, and an MCQ has a finite number of wrong answers to explain.
@JsonSerializable(createToJson: false)
class Feedback {
  const Feedback({required this.en, required this.bn});

  factory Feedback.fromJson(Map<String, dynamic> json) =>
      _$FeedbackFromJson(json);

  final String en;

  /// Bangla explanation. Grammar terms stay in English inside it.
  final String bn;
}

@JsonSerializable(createToJson: false)
class QuestionOption {
  const QuestionOption({
    required this.id,
    required this.text,
    required this.correct,
    this.feedback,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) =>
      _$QuestionOptionFromJson(json);

  final String id;
  final String text;
  final bool correct;

  /// Absent on pre-assessment options by design — the first check
  /// deliberately shows nothing (SPEC §6, Phase 1).
  final Feedback? feedback;
}

@JsonSerializable(createToJson: false)
class Question {
  const Question({
    required this.id,
    required this.rule,
    required this.instruction,
    required this.prompt,
    required this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);

  final String id;

  /// Which rule within the sub-skill this tests. Keeps pre and post banks
  /// comparable — see `tools/validate_content.dart`.
  final String rule;

  final String instruction;
  final String prompt;
  final List<QuestionOption> options;

  QuestionOption get correctOption => options.firstWhere((o) => o.correct);
}
