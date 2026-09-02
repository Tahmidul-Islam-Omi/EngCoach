import 'dart:convert';
import 'dart:io';

import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_level.dart';
import 'package:engcoach/data/models/vocabulary/vocab_question.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/vocabulary_fixture.dart';

void main() {
  VocabCourse readCourse() => VocabCourse.fromJson(
    jsonDecode(File('content/vocabulary/course.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  group('the authored course', () {
    test('parses, with six named subskills', () {
      final course = readCourse();

      expect(course.subSkills, hasLength(6));
      expect(
        course.subSkills.map((s) => s.id).toSet(),
        hasLength(6),
        reason: 'a duplicate id would silently shadow a whole competency',
      );
      for (final s in course.subSkills) {
        expect(s.title, isNotEmpty);
      }
    });

    test('the ladder can actually decide', () {
      final ladder = readCourse().ladder;
      final perLevel = readCourse().checkLength;

      expect(
        ladder.advanceAt,
        lessThanOrEqualTo(perLevel),
        reason: 'a bar above a perfect score means nobody ever climbs',
      );
      expect(
        ladder.probeAt,
        lessThan(ladder.advanceAt),
        reason: 'the probe exists for scores that fall short of advancing',
      );
      expect(
        ladder.probeAdvanceAt,
        lessThanOrEqualTo(ladder.probeSize),
        reason: 'a probe nobody can pass is a stop dressed up as a chance',
      );
      expect(ladder.topLevel, greaterThan(0));
    });

    test('the final check asks more about what was taught', () {
      final config = readCourse().finalCheck;

      expect(
        config.basePerSubSkill,
        greaterThan(0),
        reason: 'a subskill left out entirely could have been lost unnoticed',
      );
      expect(
        config.extraPerFocus,
        greaterThan(0),
        reason: 'the improvement claim rests on the taught subskills',
      );
    });
  });

  group('the level schema', () {
    test('an authored level parses', () {
      final level = VocabLevel.fromJson(levelJson());

      expect(level.level, 2);
      expect(level.title, 'Developing');
      expect(level.subSkills, hasLength(6));
      expect(level.subSkill('collocations').preAssessmentBank, hasLength(3));
      expect(
        level.chunks.first.practice.first.type,
        VocabQuestionType.collocation,
      );
    });

    test('a word card needs only word, meaning and example', () {
      final words = VocabLevel.fromJson(levelJson()).chunks.first.words;
      final bare = words.last;

      expect(bare.word, 'busy');
      expect(bare.bn, 'ব্যস্ত');
      expect(bare.example.bn, isNotEmpty);
      expect(bare.pos, isNull);
      expect(bare.usage, isNull);
      expect(
        bare.synonyms,
        isEmpty,
        reason: 'an absent list must read as empty, not blow up the parse',
      );
    });

    test('the full card keeps every optional field', () {
      final full = VocabLevel.fromJson(levelJson()).chunks.first.words.first;

      expect(full.pos, 'adjective');
      expect(full.usage, 'reluctant + to + verb');
      expect(full.synonyms, ['unwilling', 'hesitant']);
      expect(full.antonyms, ['willing', 'eager']);
      expect(full.collocations, ['reluctant to agree']);
    });

    test('the pre and post banks are different questions', () {
      final s = VocabLevel.fromJson(levelJson()).subSkill('word_meaning');

      expect(
        s.preAssessmentBank
            .map((q) => q.id)
            .toSet()
            .intersection(s.postAssessmentBank.map((q) => q.id).toSet()),
        isEmpty,
        reason: 'repeating a question would measure memory, not vocabulary',
      );
    });

    test('a plan built from stale ids drops them instead of breaking', () {
      final level = VocabLevel.fromJson(levelJson());

      expect(
        level
            .chunksFor(['collocations', 'removed_last_release'])
            .map((c) => c.subSkillId),
        ['collocations'],
      );
    });

    test('chunks come back in authored order, not the order asked for', () {
      final level = VocabLevel.fromJson(levelJson());

      expect(
        level
            .chunksFor(['collocations', 'word_meaning'])
            .map((c) => c.subSkillId),
        ['word_meaning', 'collocations'],
        reason: 'authored order is teaching order',
      );
    });
  });

  group('every authored level', () {
    // Empty until the levels are written. Deliberately not asserting that
    // files exist: this guard has to be in place before the content lands,
    // not written afterwards to fit whatever was authored.
    final files =
        Directory('content/vocabulary')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('level_'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final name = file.uri.pathSegments.last;

      test('$name holds together', () {
        final course = readCourse();
        final level = VocabLevel.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );

        expect(
          name,
          'level_${level.level}.json',
          reason: 'the file name is how the repository finds a level',
        );
        expect(level.level, lessThanOrEqualTo(course.ladder.topLevel));

        final known = course.subSkills.map((s) => s.id).toSet();
        for (final s in level.subSkills) {
          expect(known, contains(s.id));
          expect(
            s.preAssessmentBank.length,
            greaterThanOrEqualTo(
              course.ladder.questionsPerSubSkill + course.ladder.probeSize,
            ),
            reason: 'the probe draws its extra questions from this bank',
          );
          expect(
            s.postAssessmentBank.length,
            greaterThanOrEqualTo(
              course.finalCheck.basePerSubSkill +
                  course.finalCheck.extraPerFocus,
            ),
            reason: 'a focus subskill is asked about more on the final check',
          );
        }

        // The first check deliberately explains nothing; the final check and
        // practice explain every option, including the right one, so a lucky
        // guess still teaches something.
        for (final s in level.subSkills) {
          for (final q in s.preAssessmentBank) {
            for (final o in q.options) {
              expect(o.feedback, isNull, reason: '${q.id} explains too early');
            }
          }
          for (final q in s.postAssessmentBank) {
            for (final o in q.options) {
              expect(o.feedback, isNotNull, reason: '${q.id} option ${o.id}');
            }
          }
        }

        for (final c in level.chunks) {
          expect(known, contains(c.subSkillId));
          expect(c.words, isNotEmpty);
          expect(c.practice, isNotEmpty);
          for (final q in c.practice) {
            for (final o in q.options) {
              expect(o.feedback, isNotNull, reason: '${q.id} option ${o.id}');
            }
            expect(q.options.where((o) => o.correct), hasLength(1));
          }
        }

        // Ids address stored answers and drive the probe's exclude set, so a
        // duplicate would quietly score one question with another's answer.
        final ids = [
          for (final s in level.subSkills) ...[
            for (final q in s.preAssessmentBank) q.id,
            for (final q in s.postAssessmentBank) q.id,
          ],
          for (final c in level.chunks)
            for (final q in c.practice) q.id,
        ];
        expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate id');

        for (final s in level.subSkills) {
          for (final q in [...s.preAssessmentBank, ...s.postAssessmentBank]) {
            expect(
              q.options.where((o) => o.correct),
              hasLength(1),
              reason: '${q.id} must have exactly one right answer',
            );
          }
        }

        // A weak subskill with nothing to teach is a dead end in the plan.
        final taught = level.chunks.map((c) => c.subSkillId).toSet();
        for (final s in level.subSkills) {
          expect(taught, contains(s.id));
        }
      });
    }
  });
}
