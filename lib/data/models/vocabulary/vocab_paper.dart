import 'dart:math';

import 'package:flutter/foundation.dart';

import '../question.dart';
import 'vocab_course.dart';
import 'vocab_level.dart';
import 'vocab_question.dart';

/// Which of a subskill's two banks a paper is drawn from.
enum VocabPhase {
  pre,
  post;

  List<VocabQuestion> bankOf(LevelSubSkill subSkill) => switch (this) {
    VocabPhase.pre => subSkill.preAssessmentBank,
    VocabPhase.post => subSkill.postAssessmentBank,
  };
}

/// One question as a single learner sees it.
@immutable
class VocabDrawn {
  const VocabDrawn({
    required this.subSkillId,
    required this.question,
    required this.options,
  });

  /// Known to the app, never shown: naming the subskill on the question
  /// steers the answer and measures the wrong thing.
  final String subSkillId;

  final VocabQuestion question;

  /// [VocabQuestion.options] in this learner's order — a separate list, since
  /// content is parsed once and shared by every draw.
  final List<QuestionOption> options;

  String get id => question.id;
  String get correctOptionId => question.correctOption.id;

  bool isCorrect(String? optionId) =>
      optionId != null && optionId == correctOptionId;
}

/// One assembled vocabulary paper — a level check, a borderline probe, or a
/// final check — drawn once and then fixed.
@immutable
class VocabPaper {
  const VocabPaper({
    required this.level,
    required this.phase,
    required this.subSkillIds,
    required this.questions,
  });

  /// A level check: one question per subskill, so the level is measured
  /// across the whole competency set rather than on whatever the learner
  /// happens to be good at (SPEC §3).
  ///
  /// Driven by [course] rather than by the level file, so the order is the
  /// authored one and a subskill the level has no questions for is simply
  /// absent instead of shifting everything after it.
  factory VocabPaper.check(
    VocabLevel level,
    VocabCourse course, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final drawn = <VocabDrawn>[];
    final covered = <String>[];

    for (final subSkill in course.subSkills) {
      final authored = level.subSkillOrNull(subSkill.id);
      if (authored == null) continue;

      final dealt = _deal(
        authored,
        VocabPhase.pre,
        course.ladder.questionsPerSubSkill,
        const {},
        rng,
      );
      if (dealt.isEmpty) continue;

      covered.add(subSkill.id);
      drawn.addAll(dealt);
    }

    return VocabPaper(
      level: level.level,
      phase: VocabPhase.pre,
      subSkillIds: List.unmodifiable(covered),
      questions: List.unmodifiable(drawn),
    );
  }

  /// The extra questions a borderline score buys (SPEC §3).
  ///
  /// Drawn from the same bank as the check and told which questions were
  /// already asked, so the probe is new evidence rather than a second look at
  /// the same item. One question per subskill that was missed, capped at
  /// [size] — asking again about what the learner already got right would
  /// tell us nothing we do not know.
  factory VocabPaper.probe(
    VocabLevel level, {
    required Iterable<String> subSkillIds,
    required int size,
    Set<String> exclude = const {},
    Random? random,
  }) {
    final rng = random ?? Random();
    final drawn = <VocabDrawn>[];
    final covered = <String>[];

    for (final id in subSkillIds.take(size)) {
      final authored = level.subSkillOrNull(id);
      if (authored == null) continue;

      final dealt = _deal(authored, VocabPhase.pre, 1, exclude, rng);
      if (dealt.isEmpty) continue;

      covered.add(id);
      drawn.addAll(dealt);
    }

    return VocabPaper(
      level: level.level,
      phase: VocabPhase.pre,
      subSkillIds: List.unmodifiable(covered),
      questions: List.unmodifiable(drawn),
    );
  }

  /// The final check: every subskill again, and more of the ones that were
  /// taught (SPEC §15, §16).
  ///
  /// The base questions prove nothing was lost while the learner was busy
  /// elsewhere; the extra ones on [focus] are where the claim of improvement
  /// actually rests, and one question could not carry it.
  factory VocabPaper.finalCheck(
    VocabLevel level,
    VocabCourse course, {
    required Iterable<String> focus,
    Random? random,
  }) {
    final rng = random ?? Random();
    final wanted = focus.toSet();
    final drawn = <VocabDrawn>[];
    final covered = <String>[];

    for (final subSkill in course.subSkills) {
      final authored = level.subSkillOrNull(subSkill.id);
      if (authored == null) continue;

      final config = course.finalCheck;
      final count =
          config.basePerSubSkill +
          (wanted.contains(subSkill.id) ? config.extraPerFocus : 0);

      final dealt = _deal(authored, VocabPhase.post, count, const {}, rng);
      if (dealt.isEmpty) continue;

      covered.add(subSkill.id);
      drawn.addAll(dealt);
    }

    return VocabPaper(
      level: level.level,
      phase: VocabPhase.post,
      subSkillIds: List.unmodifiable(covered),
      questions: List.unmodifiable(drawn),
    );
  }

  final int level;
  final VocabPhase phase;

  /// The subskills this paper actually asked about, in authored order.
  final List<String> subSkillIds;

  final List<VocabDrawn> questions;

  int get length => questions.length;
  bool get isEmpty => questions.isEmpty;

  Set<String> get questionIds => {for (final q in questions) q.id};

  List<VocabDrawn> questionsFor(String subSkillId) => [
    for (final q in questions)
      if (q.subSkillId == subSkillId) q,
  ];

  /// Takes what the bank can give rather than throwing: a bank too small for
  /// the draw is an authoring fault, and the validator is where it is caught.
  static List<VocabDrawn> _deal(
    LevelSubSkill subSkill,
    VocabPhase phase,
    int wanted,
    Set<String> exclude,
    Random rng,
  ) {
    final bank = [
      for (final q in phase.bankOf(subSkill))
        if (!exclude.contains(q.id)) q,
    ]..shuffle(rng);

    return [
      for (final q in bank.take(min(wanted, bank.length)))
        VocabDrawn(
          subSkillId: subSkill.id,
          question: q,
          options: List.of(q.options)..shuffle(rng),
        ),
    ];
  }
}
