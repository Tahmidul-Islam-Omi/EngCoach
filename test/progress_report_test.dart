import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/models/vocabulary/vocab_chunk.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/features/progress/model/progress_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/topic_fixture.dart';

/// The evidence screen's report, built without Firestore or a widget tree.
void main() {
  final topics = [
    buildTopic(id: 'present_simple', title: 'Present Simple', subSkills: 5),
    buildTopic(id: 'articles', title: 'Articles', subSkills: 6),
    buildTopic(id: 'past_perfect', title: 'Past Perfect'),
  ];

  const course = VocabCourse(
    subSkills: [
      VocabSubSkill(id: 'word_meaning', title: 'Word meaning'),
      VocabSubSkill(id: 'collocations', title: 'Words that go together'),
      VocabSubSkill(id: 'phrasal_verbs', title: 'Phrasal verbs'),
    ],
    ladder: LadderConfig(
      questionsPerSubSkill: 1,
      advanceAt: 5,
      probeAt: 4,
      probeSize: 2,
      probeAdvanceAt: 2,
      topLevel: 4,
    ),
    finalCheck: FinalCheckConfig(basePerSubSkill: 1, extraPerFocus: 2),
  );

  ScoreSnapshot score(int percent, {DateTime? at}) => ScoreSnapshot(
    correct: percent,
    total: 100,
    percent: percent,
    takenAt: at ?? DateTime(2026, 8, 21),
    subSkills: const [],
  );

  TopicProgress progressFor(
    String id, {
    TopicStatus status = TopicStatus.learning,
    List<String> weak = const [],
    List<String> done = const [],
    ScoreSnapshot? pre,
    ScoreSnapshot? post,
  }) => TopicProgress(
    topicId: id,
    status: status,
    weakSubSkills: weak,
    completedSubSkills: done,
    preAssessment: pre,
    postAssessment: post,
  );

  ProgressReport build({
    List<TopicProgress> progress = const [],
    VocabPlan? plan,
    List<VocabChunk> planChunks = const [],
  }) => buildProgressReport(
    topics: topics,
    progress: progress,
    course: course,
    plan: plan,
    planChunks: planChunks,
  );

  group('evidence', () {
    test('a first check alone proves nothing', () {
      final report = build(
        progress: [
          progressFor('present_simple', weak: ['s1'], pre: score(60)),
        ],
      );

      expect(report.hasEvidence, isFalse);
      expect(report.overallBefore, isNull);
      expect(report.reCheckedCount, 0);
      // The topic still appears — it just has one bar, not two.
      expect(report.topics.single.before, 60);
      expect(report.topics.single.after, isNull);
    });

    test('the overall figure means the topic percentages', () {
      final report = build(
        progress: [
          progressFor('present_simple', pre: score(60), post: score(80)),
          progressFor('articles', pre: score(45), post: score(60)),
        ],
      );

      // (60 + 45) / 2 and (80 + 60) / 2 — not a pool of raw questions, so it
      // agrees with the figure Home shows.
      expect(report.overallBefore, 53);
      expect(report.overallAfter, 70);
      expect(report.reCheckedCount, 2);
    });

    test('a topic checked once is left out of the overall figure', () {
      final report = build(
        progress: [
          progressFor('present_simple', pre: score(60), post: score(80)),
          progressFor('articles', pre: score(10)),
        ],
      );

      expect(report.overallBefore, 60);
      expect(report.overallAfter, 80);
      expect(report.reCheckedCount, 1);
    });
  });

  group('grammar', () {
    test('topics are ordered weakest first', () {
      final report = build(
        progress: [
          // Authored first, and the stronger of the two.
          progressFor('present_simple', pre: score(60), post: score(80)),
          progressFor('articles', pre: score(45), post: score(60)),
        ],
      );

      expect(report.topics.map((t) => t.title), ['Articles', 'Present Simple']);
      expect(report.topics.first.gain, 15);
      expect(report.topics.last.gain, 20);
    });

    test('a tie keeps the authored order', () {
      final report = build(
        progress: [
          progressFor('articles', pre: score(50), post: score(70)),
          progressFor('present_simple', pre: score(30), post: score(70)),
        ],
      );

      expect(report.topics.map((t) => t.title), ['Present Simple', 'Articles']);
    });

    test('parts still weak exclude what has been practised', () {
      final report = build(
        progress: [
          progressFor(
            'present_simple',
            weak: ['s1', 's2', 's3'],
            done: ['s1'],
            pre: score(60),
          ),
        ],
      );

      expect(report.topics.single.partsWeak, 2);
      expect(report.topics.single.partsTotal, 5);
    });

    test('untouched topics are listed apart', () {
      final report = build(
        progress: [progressFor('present_simple', pre: score(60))],
      );

      expect(report.notStarted.map((t) => t.title), [
        'Articles',
        'Past Perfect',
      ]);
    });
  });

  group('vocabulary', () {
    VocabSubSkillScore s(String id, int correct, int total) =>
        VocabSubSkillScore(subSkillId: id, correct: correct, total: total);

    test('areas carry raw counts, in the course order', () {
      final report = build(
        plan: VocabPlan(
          level: 2,
          focusSubSkillIds: const [],
          before: [
            s('collocations', 0, 1),
            s('word_meaning', 1, 1),
            s('phrasal_verbs', 0, 1),
          ],
          after: [
            s('collocations', 3, 3),
            s('word_meaning', 1, 1),
            s('phrasal_verbs', 2, 3),
          ],
        ),
      );

      final vocabulary = report.vocabulary!;
      expect(vocabulary.cleared, isTrue);
      expect(vocabulary.level, 2);
      expect(vocabulary.topLevel, 4);

      // Course order, not the order the scores happen to be stored in.
      expect(vocabulary.areas.map((a) => a.title), [
        'Word meaning',
        'Words that go together',
        'Phrasal verbs',
      ]);

      final collocations = vocabulary.areas[1];
      expect(collocations.beforeCorrect, 0);
      expect(collocations.beforeTotal, 1);
      expect(collocations.afterCorrect, 3);
      expect(collocations.afterTotal, 3);
    });

    test('a plan with no final check yet has no after', () {
      final report = build(
        plan: VocabPlan(
          level: 2,
          focusSubSkillIds: const ['collocations'],
          before: [s('collocations', 0, 1)],
        ),
      );

      expect(report.vocabulary!.cleared, isFalse);
      expect(report.vocabulary!.areas.single.hasAfter, isFalse);
    });

    test('no plan means no vocabulary block at all', () {
      expect(build().vocabulary, isNull);
    });
  });

  group('still to work on', () {
    test('every outstanding area is listed, both sections, uncapped', () {
      final report = build(
        progress: [
          progressFor(
            'present_simple',
            weak: ['s1', 's2', 's3', 's4'],
            pre: score(40),
          ),
        ],
        plan: const VocabPlan(level: 2, focusSubSkillIds: ['collocations']),
        planChunks: const [
          VocabChunk(
            id: 'c_collocations',
            subSkillId: 'collocations',
            title: 'set',
            words: [],
            practice: [],
          ),
        ],
      );

      // Home caps at three; this screen is the profile, so it shows all five.
      expect(report.weakAreas, hasLength(5));
      expect(report.weakAreas.last.title, 'Words that go together');
      expect(report.weakAreas.last.context, 'Vocabulary Level 2');
    });
  });

  group('the dated check list', () {
    test('every check appears, newest first', () {
      final report = build(
        progress: [
          progressFor(
            'present_simple',
            pre: score(60, at: DateTime(2026, 8, 21)),
            post: score(80, at: DateTime(2026, 9, 2)),
          ),
          progressFor('articles', pre: score(45, at: DateTime(2026, 8, 28))),
        ],
        plan: VocabPlan(
          level: 2,
          focusSubSkillIds: const [],
          after: const [],
          updatedAt: DateTime(2026, 9, 4),
        ),
      );

      expect(report.checks.map((c) => c.title), [
        'Vocabulary Level 2 — final check',
        'Present Simple — second check',
        'Articles — first check',
        'Present Simple — first check',
      ]);
      expect(report.checks[1].detail, '80%, up 20 points');
      expect(report.checks.last.detail, '60%, your starting point');
    });

    test('a score that slipped says so', () {
      final report = build(
        progress: [
          progressFor(
            'present_simple',
            pre: score(70, at: DateTime(2026, 8, 21)),
            post: score(55, at: DateTime(2026, 9, 2)),
          ),
        ],
      );

      expect(report.checks.first.detail, '55%, down 15 points');
    });

    test(
      'vocabulary contributes one entry, because only one date is stored',
      () {
        final report = build(
          plan: VocabPlan(
            level: 3,
            focusSubSkillIds: const ['collocations'],
            updatedAt: DateTime(2026, 9, 4),
          ),
        );

        expect(report.checks, hasLength(1));
        expect(report.checks.single.title, 'Vocabulary — level check');
        expect(report.checks.single.detail, 'Placed at Level 3');
      },
    );

    test('nothing taken means nothing to list', () {
      expect(build().checks, isEmpty);
    });
  });
}
