import 'package:flutter/foundation.dart';

import 'assessment_paper.dart';

/// What the whole paper says about the learner, in SPEC §6 Phase 1 terms.
///
/// Read off qualified sub-skills rather than the overall percentage,
/// deliberately: the product decides what to teach one sub-skill at a time,
/// so "67% overall" is not an answer to "what do I skip?".
enum AssessmentOutcome {
  /// Every sub-skill qualified — the learning phase becomes optional.
  fullPass,

  /// Some qualified, some not — only the weak ones are prioritised.
  partial,

  /// Nothing qualified — the full learning path is recommended.
  insufficient,
}

/// How one sub-skill went.
@immutable
class SubSkillScore {
  const SubSkillScore({
    required this.subSkillId,
    required this.title,
    required this.correct,
    required this.total,
    required this.qualified,
  });

  final String subSkillId;
  final String title;
  final int correct;
  final int total;

  /// Reached the topic's qualifying score, so this sub-skill may be skipped.
  final bool qualified;

  int get percent => total == 0 ? 0 : (correct * 100 / total).round();
}

/// A scored paper.
@immutable
class AssessmentResult {
  const AssessmentResult({
    required this.topicId,
    required this.phase,
    required this.subSkills,
    required this.answers,
  });

  /// Scores [answers] — question id to chosen option id — against [paper].
  ///
  /// Anything missing counts wrong, so an abandoned paper still scores. Only
  /// the paper's own questions count, so a stale answer from an earlier draw
  /// cannot leak into the total.
  factory AssessmentResult.score(
    AssessmentPaper paper,
    Map<String, String> answers,
  ) {
    final scores = <SubSkillScore>[];

    for (final subSkill in paper.subSkills) {
      final drawn = paper.questionsFor(subSkill.id);
      var correct = 0;
      for (final question in drawn) {
        if (question.isCorrect(answers[question.id])) correct++;
      }

      scores.add(
        SubSkillScore(
          subSkillId: subSkill.id,
          title: subSkill.title,
          correct: correct,
          total: drawn.length,
          // Nothing asked is not a pass: qualifying means having shown it.
          qualified: drawn.isNotEmpty && correct >= paper.qualifyingScore,
        ),
      );
    }

    return AssessmentResult(
      topicId: paper.topicId,
      phase: paper.phase,
      subSkills: List.unmodifiable(scores),
      answers: Map.unmodifiable(answers),
    );
  }

  final String topicId;
  final AssessmentPhase phase;

  /// One entry per sub-skill, in authored order.
  final List<SubSkillScore> subSkills;

  /// What was chosen, kept for the result screen and for the mistake log
  /// (SPEC §8) — the score alone cannot say which option was picked.
  final Map<String, String> answers;

  int get correct => subSkills.fold(0, (n, s) => n + s.correct);
  int get total => subSkills.fold(0, (n, s) => n + s.total);
  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  /// Sub-skills to teach, in authored order — which is teaching order.
  List<SubSkillScore> get weakSubSkills =>
      [for (final s in subSkills) if (!s.qualified) s];

  List<SubSkillScore> get strongSubSkills =>
      [for (final s in subSkills) if (s.qualified) s];

  AssessmentOutcome get outcome {
    // An empty paper proves nothing; it must not read as a pass.
    if (total == 0) return AssessmentOutcome.insufficient;
    if (weakSubSkills.isEmpty) return AssessmentOutcome.fullPass;
    if (strongSubSkills.isEmpty) return AssessmentOutcome.insufficient;
    return AssessmentOutcome.partial;
  }
}
