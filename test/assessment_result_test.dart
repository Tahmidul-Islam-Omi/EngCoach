import 'dart:math';

import 'package:engcoach/data/models/assessment_paper.dart';
import 'package:engcoach/data/models/assessment_result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/topic_fixture.dart';

void main() {
  AssessmentPaper paperOf({
    int subSkills = 3,
    int questionsPerSubSkill = 3,
    int qualifyingScore = 3,
    int seed = 1,
  }) {
    return AssessmentPaper.draw(
      buildTopic(
        subSkills: subSkills,
        questionsPerSubSkill: questionsPerSubSkill,
        qualifyingScore: qualifyingScore,
      ),
      random: Random(seed),
    );
  }

  /// Answers every question, getting the first [correct] of each sub-skill
  /// right and deliberately missing the rest.
  Map<String, String> answers(AssessmentPaper paper, {required int correct}) {
    final out = <String, String>{};
    for (final subSkill in paper.subSkills) {
      final drawn = paper.questionsFor(subSkill.id);
      for (var i = 0; i < drawn.length; i++) {
        final q = drawn[i];
        out[q.id] = i < correct
            ? q.correctOptionId
            : q.options.firstWhere((o) => !o.correct).id;
      }
    }
    return out;
  }

  group('scoring', () {
    test('counts by option id, so the shuffle cannot change a score', () {
      final paper = paperOf();
      final result = AssessmentResult.score(paper, answers(paper, correct: 3));

      expect(result.correct, 9);
      expect(result.total, 9);
      expect(result.percent, 100);
    });

    test('an unanswered question counts wrong', () {
      final paper = paperOf();
      final partial = answers(paper, correct: 3)
        ..remove(paper.questions.first.id);

      final result = AssessmentResult.score(paper, partial);

      expect(result.correct, 8);
      expect(result.total, 9, reason: 'skipping does not shorten the paper');
    });

    test('an answer that is not one of the options counts wrong', () {
      final paper = paperOf();
      final bogus = answers(paper, correct: 3)
        ..[paper.questions.first.id] = 'not-an-option';

      expect(AssessmentResult.score(paper, bogus).correct, 8);
    });

    test('an answer to a question not on the paper is ignored', () {
      final paper = paperOf();
      final stale = answers(paper, correct: 3)..['s1-pre-99'] = 'anything';

      final result = AssessmentResult.score(paper, stale);

      expect(result.correct, 9);
      expect(result.total, 9);
    });

    test('nothing answered scores zero', () {
      final paper = paperOf();
      final result = AssessmentResult.score(paper, const {});

      expect(result.correct, 0);
      expect(result.percent, 0);
      expect(result.outcome, AssessmentOutcome.insufficient);
    });

    test('rounds the percentage', () {
      final paper = paperOf(subSkills: 1, questionsPerSubSkill: 3);
      final result = AssessmentResult.score(paper, answers(paper, correct: 2));

      expect(result.percent, 67);
    });
  });

  group('qualifying', () {
    test('the qualifying score itself qualifies', () {
      final paper = paperOf(qualifyingScore: 2);
      final result = AssessmentResult.score(paper, answers(paper, correct: 2));

      expect(result.subSkills.every((s) => s.qualified), isTrue);
    });

    test('one short does not qualify', () {
      final paper = paperOf(qualifyingScore: 3);
      final result = AssessmentResult.score(paper, answers(paper, correct: 2));

      expect(result.subSkills.every((s) => s.qualified), isFalse);
      expect(result.weakSubSkills, hasLength(3));
    });

    test('a sub-skill nothing was asked about cannot qualify', () {
      final paper = AssessmentPaper.draw(
        buildTopic(bankSize: 0),
        random: Random(1),
      );
      final result = AssessmentResult.score(paper, const {});

      expect(result.subSkills, hasLength(3));
      expect(result.subSkills.every((s) => s.total == 0), isTrue);
      expect(result.subSkills.every((s) => s.qualified), isFalse);
    });

    test('scores each sub-skill on its own questions', () {
      final paper = paperOf();
      final chosen = <String, String>{};
      for (final subSkill in paper.subSkills) {
        // s1 perfect, s2 and s3 wrong throughout.
        final right = subSkill.id == 's1';
        for (final q in paper.questionsFor(subSkill.id)) {
          chosen[q.id] = right
              ? q.correctOptionId
              : q.options.firstWhere((o) => !o.correct).id;
        }
      }

      final result = AssessmentResult.score(paper, chosen);

      expect(result.subSkills.map((s) => s.correct), [3, 0, 0]);
      expect(result.subSkills.map((s) => s.qualified), [true, false, false]);
      expect(result.weakSubSkills.map((s) => s.subSkillId), ['s2', 's3']);
      expect(result.strongSubSkills.map((s) => s.subSkillId), ['s1']);
    });

    test('reports weak sub-skills in authored order', () {
      final paper = paperOf(subSkills: 4);
      final chosen = <String, String>{};
      for (final subSkill in paper.subSkills) {
        final right = subSkill.id == 's2';
        for (final q in paper.questionsFor(subSkill.id)) {
          chosen[q.id] = right
              ? q.correctOptionId
              : q.options.firstWhere((o) => !o.correct).id;
        }
      }

      expect(
        AssessmentResult.score(
          paper,
          chosen,
        ).weakSubSkills.map((s) => s.subSkillId),
        ['s1', 's3', 's4'],
      );
    });
  });

  group('outcome', () {
    test('every sub-skill qualified is a full pass', () {
      final paper = paperOf();
      expect(
        AssessmentResult.score(paper, answers(paper, correct: 3)).outcome,
        AssessmentOutcome.fullPass,
      );
    });

    test('some qualified is partial', () {
      final paper = paperOf();
      final chosen = <String, String>{};
      for (final subSkill in paper.subSkills) {
        final right = subSkill.id == 's1';
        for (final q in paper.questionsFor(subSkill.id)) {
          chosen[q.id] = right
              ? q.correctOptionId
              : q.options.firstWhere((o) => !o.correct).id;
        }
      }

      expect(
        AssessmentResult.score(paper, chosen).outcome,
        AssessmentOutcome.partial,
      );
    });

    test('scoring well but qualifying nowhere still recommends everything', () {
      // 2 of 3 in every sub-skill: 67% overall, and not one sub-skill proven.
      final paper = paperOf(qualifyingScore: 3);
      final result = AssessmentResult.score(paper, answers(paper, correct: 2));

      expect(result.percent, 67);
      expect(result.outcome, AssessmentOutcome.insufficient);
    });
  });

  group('the answers it keeps', () {
    test('are kept for the result screen and cannot be edited after', () {
      final paper = paperOf();
      final result = AssessmentResult.score(paper, answers(paper, correct: 1));

      final first = paper.questions.first;
      expect(result.answers[first.id], first.correctOptionId);
      expect(() => result.answers['x'] = 'y', throwsUnsupportedError);
    });
  });
}
