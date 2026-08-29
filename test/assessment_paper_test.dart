import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/models/assessment_paper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/topic_fixture.dart';

void main() {
  group('drawing', () {
    test('takes the configured number from every sub-skill', () {
      final topic = buildTopic(subSkills: 3, questionsPerSubSkill: 3);
      final paper = AssessmentPaper.draw(topic, random: Random(1));

      expect(paper.length, 9);
      for (final s in topic.subSkills) {
        expect(paper.questionsFor(s.id), hasLength(3));
      }
    });

    test('keeps sub-skills grouped in authored order', () {
      final paper = AssessmentPaper.draw(
        buildTopic(subSkills: 3),
        random: Random(2),
      );

      expect(
        paper.questions.map((q) => q.subSkillId),
        ['s1', 's1', 's1', 's2', 's2', 's2', 's3', 's3', 's3'],
      );
    });

    test('never asks the same question twice, whatever the seed', () {
      for (var seed = 0; seed < 50; seed++) {
        final paper = AssessmentPaper.draw(
          buildTopic(),
          random: Random(seed),
        );
        final ids = paper.questions.map((q) => q.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'seed $seed');
      }
    });

    test('draws from the bank the phase names', () {
      final topic = buildTopic();

      final pre = AssessmentPaper.draw(topic, random: Random(3));
      expect(pre.questions.every((q) => q.id.contains('-pre-')), isTrue);
      expect(pre.phase, AssessmentPhase.pre);

      final post = AssessmentPaper.draw(
        topic,
        phase: AssessmentPhase.post,
        random: Random(3),
      );
      expect(post.questions.every((q) => q.id.contains('-post-')), isTrue);
    });

    test('the same seed deals the same paper', () {
      final topic = buildTopic();
      final a = AssessmentPaper.draw(topic, random: Random(7));
      final b = AssessmentPaper.draw(topic, random: Random(7));

      expect(
        a.questions.map((q) => q.id),
        b.questions.map((q) => q.id),
      );
      expect(
        a.questions.first.options.map((o) => o.id),
        b.questions.first.options.map((o) => o.id),
      );
    });

    test('different seeds deal different papers', () {
      final topic = buildTopic();
      final papers = [
        for (var seed = 0; seed < 20; seed++)
          AssessmentPaper.draw(topic, random: Random(seed))
              .questions
              .map((q) => q.id)
              .join(','),
      ];

      // Two learners should rarely sit the same paper — 20 draws from a bank
      // of 6 should not collapse to one arrangement.
      expect(papers.toSet().length, greaterThan(1));
    });

    test('asks for what exists when the bank is short', () {
      final paper = AssessmentPaper.draw(
        buildTopic(bankSize: 2, questionsPerSubSkill: 3),
        random: Random(4),
      );

      expect(paper.questionsFor('s1'), hasLength(2));
      expect(paper.length, 6);
    });

    test('a sub-skill with an empty bank still belongs to the paper', () {
      final topic = buildTopic(bankSize: 0);
      final paper = AssessmentPaper.draw(topic, random: Random(5));

      expect(paper.isEmpty, isTrue);
      expect(paper.subSkills, hasLength(3));
    });
  });

  group('option order', () {
    test('shuffles without losing or duplicating an option', () {
      final topic = buildTopic();
      final paper = AssessmentPaper.draw(topic, random: Random(11));

      for (final drawn in paper.questions) {
        expect(
          drawn.options.map((o) => o.id).toSet(),
          drawn.question.options.map((o) => o.id).toSet(),
        );
        expect(drawn.options, hasLength(drawn.question.options.length));
      }
    });

    test('leaves exactly one correct option in place', () {
      final paper = AssessmentPaper.draw(buildTopic(), random: Random(12));

      for (final drawn in paper.questions) {
        expect(drawn.options.where((o) => o.correct), hasLength(1));
        expect(drawn.correctOptionId, drawn.options.firstWhere((o) => o.correct).id);
      }
    });

    test('does not reorder the topic it drew from', () {
      // Content is parsed once and cached, so a shuffle in place would
      // scramble the options for every later draw.
      final topic = buildTopic();
      final before = topic.subSkills
          .expand((s) => s.preAssessmentBank)
          .map((q) => q.options.map((o) => o.id).join())
          .toList();

      for (var seed = 0; seed < 10; seed++) {
        AssessmentPaper.draw(topic, random: Random(seed));
      }

      final after = topic.subSkills
          .expand((s) => s.preAssessmentBank)
          .map((q) => q.options.map((o) => o.id).join())
          .toList();

      expect(after, before);
    });

    test('does move the options around across draws', () {
      final topic = buildTopic(subSkills: 1, bankSize: 1);
      final orders = {
        for (var seed = 0; seed < 20; seed++)
          AssessmentPaper.draw(topic, random: Random(seed))
              .questions
              .first
              .options
              .map((o) => o.id)
              .join(),
      };

      expect(orders.length, greaterThan(1));
    });
  });

  group('authored content', () {
    test('every topic deals a full paper of distinct questions', () {
      final files = Directory('content')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));

      expect(files, isNotEmpty, reason: 'no topic JSON found');

      for (final file in files) {
        final topic = Topic.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );

        for (final phase in AssessmentPhase.values) {
          final paper = AssessmentPaper.draw(
            topic,
            phase: phase,
            random: Random(topic.id.hashCode),
          );

          expect(
            paper.length,
            topic.preAssessmentLength,
            reason: '${topic.id} (${phase.name}) drew a short paper',
          );
          expect(
            paper.questions.map((q) => q.id).toSet(),
            hasLength(paper.length),
            reason: '${topic.id} (${phase.name}) repeated a question',
          );
          for (final drawn in paper.questions) {
            expect(
              drawn.options.where((o) => o.correct),
              hasLength(1),
              reason: '${drawn.id} has no single correct option',
            );
          }
        }
      }
    });
  });
}
