import 'dart:math';

import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_ladder.dart';
import 'package:engcoach/data/models/vocabulary/vocab_level.dart';
import 'package:engcoach/data/models/vocabulary/vocab_paper.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/vocabulary_fixture.dart';

void main() {
  final course = VocabCourse.fromJson(courseJson());
  final level = VocabLevel.fromJson(levelJson(level: 2));
  const ladder = VocabLadder(
    LadderConfig(
      questionsPerSubSkill: 1,
      advanceAt: 5,
      probeAt: 4,
      probeSize: 2,
      probeAdvanceAt: 2,
      topLevel: 4,
    ),
  );

  /// A scored level, named by what the learner got wrong.
  VocabLevelResult scored(
    int at, {
    List<String> wrong = const [],
    List<String> asked = vocabSubSkillIds,
  }) => VocabLevelResult(
    level: at,
    phase: VocabPhase.pre,
    subSkills: [
      for (final id in asked)
        VocabSubSkillScore(
          subSkillId: id,
          correct: wrong.contains(id) ? 0 : 1,
          total: 1,
        ),
    ],
    answers: const {},
  );

  group('the level check', () {
    test('asks about every subskill once, in authored order', () {
      final paper = VocabPaper.check(level, course, random: Random(1));

      expect(paper.length, 6);
      expect(paper.subSkillIds, vocabSubSkillIds);
      expect(paper.questions.map((q) => q.subSkillId), vocabSubSkillIds);
    });

    test('every drawn question keeps exactly one correct option', () {
      final paper = VocabPaper.check(level, course, random: Random(7));

      for (final q in paper.questions) {
        expect(q.options, hasLength(4));
        expect(q.options.where((o) => o.correct), hasLength(1));
        expect(
          q.options.map((o) => o.id),
          contains(q.correctOptionId),
          reason: 'scoring is by option id, so the shuffle must keep it',
        );
      }
    });

    test('two learners do not sit the same paper', () {
      final a = VocabPaper.check(level, course, random: Random(1));
      final b = VocabPaper.check(level, course, random: Random(2));

      expect(a.questionIds, isNot(b.questionIds));
    });

    test('a subskill this level does not author is left out', () {
      final thin = VocabLevel.fromJson(
        levelJson(subSkills: const ['word_meaning', 'collocations']),
      );
      final paper = VocabPaper.check(thin, course, random: Random(1));

      expect(paper.subSkillIds, ['word_meaning', 'collocations']);
      expect(paper.length, 2);
    });
  });

  group('the probe', () {
    test('asks only about what was missed, and never twice', () {
      final check = VocabPaper.check(level, course, random: Random(3));
      final probe = VocabPaper.probe(
        level,
        subSkillIds: const ['collocations', 'phrasal_verbs'],
        size: 2,
        exclude: check.questionIds,
        random: Random(4),
      );

      expect(probe.subSkillIds, ['collocations', 'phrasal_verbs']);
      expect(
        probe.questionIds.intersection(check.questionIds),
        isEmpty,
        reason: 'a second look at the same item is not new evidence',
      );
    });

    test('never draws more than the ladder pays for', () {
      final probe = VocabPaper.probe(
        level,
        subSkillIds: const ['word_meaning', 'word_usage', 'collocations'],
        size: 2,
        random: Random(5),
      );

      expect(probe.length, 2);
    });
  });

  group('the decision', () {
    test('a clear pass climbs', () {
      expect(ladder.afterCheck(scored(2)), isA<ClimbTo>());
      expect((ladder.afterCheck(scored(2)) as ClimbTo).level, 3);
    });

    test('one short still climbs', () {
      final d = ladder.afterCheck(scored(2, wrong: const ['collocations']));

      expect(d, isA<ClimbTo>());
    });

    test('borderline buys evidence on exactly what was missed', () {
      final d = ladder.afterCheck(
        scored(2, wrong: const ['collocations', 'word_formation']),
      );

      expect(d, isA<ProbeHere>());
      expect(
        (d as ProbeHere).subSkillIds,
        ['collocations', 'word_formation'],
        reason: 'authored order, not the order they were missed in',
      );
      expect(d.level, 2);
    });

    test('below the band it settles without asking more', () {
      final d = ladder.afterCheck(
        scored(
          2,
          wrong: const ['collocations', 'word_formation', 'word_usage'],
        ),
      );

      expect(
        d,
        isA<SettleAt>(),
        reason: 'a struggling learner should not be asked to keep going',
      );
    });

    test('climbing off the top settles at the top', () {
      final d = ladder.afterCheck(scored(4));

      expect(d, isA<SettleAt>());
      expect((d as SettleAt).level, 4);
    });

    test('a passed probe climbs, a failed one settles', () {
      final passed = scored(2, asked: const ['collocations', 'word_formation']);
      final failed = scored(
        2,
        asked: const ['collocations', 'word_formation'],
        wrong: const ['collocations'],
      );

      expect(ladder.afterProbe(passed), isA<ClimbTo>());
      expect(ladder.afterProbe(failed), isA<SettleAt>());
    });
  });

  group('the profile', () {
    test('aggregates every level the learner sat', () {
      final profile = VocabProfile.of(
        course: course,
        results: [
          scored(1),
          scored(2),
          scored(3, wrong: const ['collocations']),
        ],
        level: 3,
      );

      final collocations = profile.scoreFor('collocations')!;
      expect(
        collocations.total,
        3,
        reason: 'one right answer is a signal; three attempts are evidence',
      );
      expect(collocations.correct, 2);
      expect(profile.scoreFor('word_meaning')!.correct, 3);
    });

    test('focus comes from the settled level only', () {
      final profile = VocabProfile.of(
        course: course,
        results: [
          scored(1, wrong: const ['phrasal_verbs']),
          scored(2, wrong: const ['collocations']),
        ],
        level: 2,
      );

      expect(
        profile.focusSubSkillIds,
        ['collocations'],
        reason: 'a Level 1 slip says nothing about Level 2 words',
      );
    });

    test('focus keeps authored order', () {
      final profile = VocabProfile.of(
        course: course,
        results: [
          scored(2, wrong: const ['word_formation', 'word_usage']),
        ],
        level: 2,
      );

      expect(profile.focusSubSkillIds, ['word_usage', 'word_formation']);
    });

    test('a clean settle has nothing to teach', () {
      final profile = VocabProfile.of(
        course: course,
        results: [scored(1), scored(2)],
        level: 2,
      );

      expect(profile.allClear, isTrue);
    });
  });

  group('the final check', () {
    test('covers everything and leans on what was taught', () {
      final paper = VocabPaper.finalCheck(
        level,
        course,
        focus: const ['collocations', 'phrasal_verbs'],
        random: Random(9),
      );

      expect(paper.phase, VocabPhase.post);
      expect(paper.questionsFor('word_meaning'), hasLength(1));
      expect(paper.questionsFor('collocations'), hasLength(3));
      expect(paper.questionsFor('phrasal_verbs'), hasLength(3));
      expect(paper.length, 4 + 3 + 3);
    });

    test('draws from the post bank, never the pre one', () {
      final paper = VocabPaper.finalCheck(
        level,
        course,
        focus: const [],
        random: Random(9),
      );

      expect(paper.questions.every((q) => q.id.contains('-post-')), isTrue);
    });
  });
}
