import 'dart:math';

import 'package:flutter/foundation.dart';

import 'question.dart';
import 'topic.dart';
import 'topic_status.dart';

/// Which of a sub-skill's two banks a paper is drawn from.
///
/// The two are authored to cover the same rules in the same proportion, so
/// the same drawing and scoring code serves both — that equivalence is the
/// whole basis of the improvement figure in SPEC §6.
enum AssessmentPhase {
  pre,
  post;

  List<Question> bankOf(SubSkill subSkill) => switch (this) {
    AssessmentPhase.pre => subSkill.preAssessmentBank,
    AssessmentPhase.post => subSkill.postAssessmentBank,
  };

  /// How far finishing this phase carries a topic (SPEC §7).
  ///
  /// "How far", not "to" — progress is one-way, so this is the floor a
  /// result establishes, never a value to assign outright. Retaking the
  /// first check on a finished topic must not undo it.
  TopicStatus get reaches => switch (this) {
    AssessmentPhase.pre => TopicStatus.tested,
    AssessmentPhase.post => TopicStatus.completed,
  };
}

/// One question as a single learner sees it: which sub-skill it came from,
/// and the order its options were dealt in.
@immutable
class DrawnQuestion {
  const DrawnQuestion({
    required this.subSkillId,
    required this.question,
    required this.options,
  });

  final String subSkillId;
  final Question question;

  /// [Question.options] in this learner's order.
  ///
  /// A separate list rather than a shuffle in place: content is parsed once
  /// and cached for the life of the app, so shuffling the model's own list
  /// would reorder it for every later draw and for anyone reading it at the
  /// same time.
  final List<QuestionOption> options;

  String get id => question.id;
  String get correctOptionId => question.correctOption.id;

  /// Scored by option id, so it holds however the options were dealt.
  bool isCorrect(String? optionId) =>
      optionId != null && optionId == correctOptionId;
}

/// One assembled assessment — the questions this learner will actually be
/// asked, drawn once and then fixed.
@immutable
class AssessmentPaper {
  const AssessmentPaper({
    required this.topicId,
    required this.phase,
    required this.subSkills,
    required this.questions,
    required this.qualifyingScore,
  });

  /// Deals a paper: [AssessmentConfig.questionsPerSubSkill] questions from
  /// every sub-skill's bank, each with its options shuffled.
  ///
  /// Questions stay grouped by sub-skill in authored order. The alternative —
  /// shuffling the whole paper — would make the learner switch rule every
  /// question for no gain, since the draw is already unpredictable within
  /// each bank.
  ///
  /// Pass [random] to make a draw repeatable; production leaves it null.
  factory AssessmentPaper.draw(
    Topic topic, {
    AssessmentPhase phase = AssessmentPhase.pre,
    Random? random,
  }) {
    final rng = random ?? Random();
    final questions = <DrawnQuestion>[];

    for (final subSkill in topic.subSkills) {
      final bank = phase.bankOf(subSkill);
      // A bank too small for the configured draw is an authoring fault the
      // validator catches. At runtime, ask what exists rather than crash.
      final wanted = min(
        topic.assessmentConfig.questionsPerSubSkill,
        bank.length,
      );

      final dealt = List.of(bank)..shuffle(rng);
      for (final question in dealt.take(wanted)) {
        questions.add(
          DrawnQuestion(
            subSkillId: subSkill.id,
            question: question,
            options: List.of(question.options)..shuffle(rng),
          ),
        );
      }
    }

    return AssessmentPaper(
      topicId: topic.id,
      phase: phase,
      subSkills: topic.subSkills,
      questions: List.unmodifiable(questions),
      qualifyingScore: topic.assessmentConfig.qualifyingScore,
    );
  }

  final String topicId;
  final AssessmentPhase phase;

  /// Every sub-skill the paper covers, in authored order — including any
  /// that produced no questions, so scoring can still report on it.
  final List<SubSkill> subSkills;

  final List<DrawnQuestion> questions;

  /// Correct answers needed within one sub-skill to skip it.
  final int qualifyingScore;

  int get length => questions.length;
  bool get isEmpty => questions.isEmpty;

  List<DrawnQuestion> questionsFor(String subSkillId) => [
    for (final q in questions)
      if (q.subSkillId == subSkillId) q,
  ];
}
