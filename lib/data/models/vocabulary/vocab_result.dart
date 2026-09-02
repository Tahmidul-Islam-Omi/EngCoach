import 'package:flutter/foundation.dart';

import 'vocab_paper.dart';

/// How one subskill went on one paper.
@immutable
class VocabSubSkillScore {
  const VocabSubSkillScore({
    required this.subSkillId,
    required this.correct,
    required this.total,
  });

  final String subSkillId;
  final int correct;
  final int total;

  bool get clean => total > 0 && correct == total;
  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  VocabSubSkillScore plus(VocabSubSkillScore other) => VocabSubSkillScore(
    subSkillId: subSkillId,
    correct: correct + other.correct,
    total: total + other.total,
  );
}

/// A scored vocabulary paper.
@immutable
class VocabLevelResult {
  const VocabLevelResult({
    required this.level,
    required this.phase,
    required this.subSkills,
    required this.answers,
  });

  /// Scores [answers] — question id to chosen option id — against [paper].
  ///
  /// Anything unanswered counts wrong, so an abandoned paper still scores,
  /// and only this paper's questions count, so an answer left over from an
  /// earlier draw cannot leak into the total.
  factory VocabLevelResult.score(
    VocabPaper paper,
    Map<String, String> answers,
  ) {
    final scores = <VocabSubSkillScore>[];

    for (final id in paper.subSkillIds) {
      final drawn = paper.questionsFor(id);
      var correct = 0;
      for (final q in drawn) {
        if (q.isCorrect(answers[q.id])) correct++;
      }
      scores.add(
        VocabSubSkillScore(
          subSkillId: id,
          correct: correct,
          total: drawn.length,
        ),
      );
    }

    return VocabLevelResult(
      level: paper.level,
      phase: paper.phase,
      subSkills: List.unmodifiable(scores),
      answers: Map.unmodifiable(answers),
    );
  }

  final int level;
  final VocabPhase phase;

  /// One entry per subskill the paper asked about, in authored order.
  final List<VocabSubSkillScore> subSkills;

  final Map<String, String> answers;

  int get correct => subSkills.fold(0, (n, s) => n + s.correct);
  int get total => subSkills.fold(0, (n, s) => n + s.total);
  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  /// Subskills the learner did not get clean, in authored order.
  ///
  /// What the probe asks about next, and what the plan is built from.
  List<String> get missed => [
    for (final s in subSkills)
      if (!s.clean) s.subSkillId,
  ];
}
