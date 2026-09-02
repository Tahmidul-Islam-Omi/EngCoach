import 'package:json_annotation/json_annotation.dart';

import '../question.dart';

// Content is read-only in the app: authored in JSON, parsed once, never
// written back.

part 'vocab_question.g.dart';

/// What the learner is asked to do with a word (SPEC §10).
///
/// Grammar items carry a `rule`; vocabulary items carry a type, because a
/// vocabulary bank varies by the kind of knowledge it demands rather than by
/// which rule it covers. It is what lets the post-assessment mirror the pre
/// one — same subskill, same types, different words (SPEC §15).
///
/// Production ("make a sentence using reluctant") is deliberately absent:
/// nothing in V1 can grade free text, and an ungraded question teaches the
/// learner that answers do not matter.
enum VocabQuestionType {
  /// What does *reluctant* mean?
  @JsonValue('meaning')
  meaning,

  /// What does it mean *in this sentence*?
  @JsonValue('contextual')
  contextual,

  /// Which sentence uses it correctly?
  @JsonValue('usage')
  usage,

  @JsonValue('synonym_antonym')
  synonymAntonym,

  /// She was reluctant ___ accept the offer.
  @JsonValue('collocation')
  collocation,

  /// Complete the sentence from options — retrieval, not recognition.
  @JsonValue('recall')
  recall,
}

/// One vocabulary question, in a check or in practice.
///
/// Reuses [QuestionOption] and its [Feedback] unchanged: the answer machinery
/// is the same as grammar's, and forking it would mean two option widgets and
/// two scorers that must agree forever.
@JsonSerializable(createToJson: false)
class VocabQuestion {
  const VocabQuestion({
    required this.id,
    required this.type,
    required this.instruction,
    required this.prompt,
    required this.options,
  });

  factory VocabQuestion.fromJson(Map<String, dynamic> json) =>
      _$VocabQuestionFromJson(json);

  final String id;
  final VocabQuestionType type;
  final String instruction;
  final String prompt;
  final List<QuestionOption> options;

  QuestionOption get correctOption => options.firstWhere((o) => o.correct);
}
