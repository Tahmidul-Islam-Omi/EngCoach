import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/models/vocabulary/vocab_chunk.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/features/home/model/home_state.dart';
import 'package:engcoach/features/home/model/next_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/topic_fixture.dart';

/// The rule that decides what Home puts at the top, exercised without
/// Firestore or a widget tree — every input is already a plain object.
void main() {
  final grammar = [
    buildTopic(id: 'present_simple', title: 'Present Simple'),
    buildTopic(id: 'articles', title: 'Articles'),
  ];

  const course = VocabCourse(
    subSkills: [
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

  VocabChunk chunk(String id, String subSkillId) => VocabChunk(
    id: id,
    subSkillId: subSkillId,
    title: id,
    words: const [],
    practice: const [],
  );

  final planChunks = [
    chunk('c_collocations', 'collocations'),
    chunk('c_phrasal', 'phrasal_verbs'),
  ];

  TopicProgress topic(
    String id, {
    required TopicStatus status,
    List<String> weak = const [],
    List<String> done = const [],
    DateTime? at,
  }) => TopicProgress(
    topicId: id,
    status: status,
    weakSubSkills: weak,
    completedSubSkills: done,
    updatedAt: at,
  );

  NextStep decide({
    List<TopicProgress> progress = const [],
    VocabPlan? plan,
    List<VocabChunk> chunks = const [],
  }) => nextStep(
    topics: grammar,
    progress: progress,
    plan: plan,
    planChunks: chunks,
    topLevel: course.ladder.topLevel,
  );

  group('nothing started', () {
    test('offers the first topic', () {
      expect(decide(), isA<StartFirstTopic>());
    });
  });

  group('grammar', () {
    test('a part-taught topic names the next area', () {
      final step = decide(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1', 's2', 's3'],
            done: ['s1'],
          ),
        ],
      );

      expect(
        step,
        isA<ContinueTopic>()
            .having((s) => s.topicId, 'topicId', 'present_simple')
            .having((s) => s.done, 'done', 1)
            .having((s) => s.total, 'total', 3)
            .having((s) => s.nextArea, 'nextArea', 'Sub-skill 2'),
      );
    });

    test('a checked but untouched topic offers the lessons', () {
      final step = decide(
        progress: [
          topic('articles', status: TopicStatus.tested, weak: ['s1', 's2']),
        ],
      );

      expect(
        step,
        isA<StartTopicLearning>().having((s) => s.title, 'title', 'Articles'),
      );
    });

    test('every area practised offers the post-check', () {
      final step = decide(
        progress: [
          topic(
            'articles',
            status: TopicStatus.learning,
            weak: ['s1', 's2'],
            done: ['s1', 's2'],
          ),
        ],
      );

      expect(step, isA<TakeTopicPostCheck>());
    });

    test('a topic ready to prove outranks one barely begun', () {
      final step = decide(
        progress: [
          // Authored first, so order alone would pick it.
          topic(
            'present_simple',
            status: TopicStatus.tested,
            weak: ['s1', 's2'],
          ),
          topic(
            'articles',
            status: TopicStatus.learning,
            weak: ['s1'],
            done: ['s1'],
          ),
        ],
      );

      expect(
        step,
        isA<TakeTopicPostCheck>().having(
          (s) => s.topicId,
          'topicId',
          'articles',
        ),
      );
    });

    test('a completed topic is not offered again', () {
      final step = decide(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.completed,
            weak: ['s1'],
            done: ['s1'],
          ),
        ],
      );

      expect(
        step,
        isA<StartNewTopic>().having((s) => s.topicId, 'topicId', 'articles'),
      );
    });
  });

  group('vocabulary', () {
    test('unfinished word sets continue the level', () {
      final step = decide(
        plan: const VocabPlan(
          level: 2,
          focusSubSkillIds: ['collocations', 'phrasal_verbs'],
          completedChunkIds: ['c_collocations'],
        ),
        chunks: planChunks,
      );

      expect(
        step,
        isA<ContinueVocabulary>()
            .having((s) => s.level, 'level', 2)
            .having((s) => s.done, 'done', 1)
            .having((s) => s.total, 'total', 2),
      );
    });

    test('every set finished offers the final check', () {
      final step = decide(
        plan: const VocabPlan(
          level: 2,
          focusSubSkillIds: ['collocations', 'phrasal_verbs'],
          completedChunkIds: ['c_collocations', 'c_phrasal'],
        ),
        chunks: planChunks,
      );

      expect(
        step,
        isA<TakeVocabularyFinalCheck>().having((s) => s.level, 'level', 2),
      );
    });

    test('a cleared level offers the rung above', () {
      final step = decide(
        plan: const VocabPlan(level: 2, focusSubSkillIds: []),
      );

      expect(
        step,
        isA<CheckNextVocabularyLevel>().having((s) => s.level, 'level', 3),
      );
    });

    test('the top level cleared is not a dead end', () {
      final step = decide(
        progress: [
          for (final t in grammar)
            topic(t.id, status: TopicStatus.completed, weak: const []),
        ],
        plan: const VocabPlan(level: 4, focusSubSkillIds: []),
      );

      expect(step, isA<NothingLeft>());
    });

    test('grammar exhausted with no vocabulary plan offers the check', () {
      final step = decide(
        progress: [
          for (final t in grammar)
            topic(t.id, status: TopicStatus.completed, weak: const []),
        ],
      );

      expect(step, isA<StartVocabulary>());
    });
  });

  group('the section touched last wins the hero', () {
    final older = DateTime(2026, 9, 1);
    final newer = DateTime(2026, 9, 4);

    final grammarWork = [
      topic(
        'present_simple',
        status: TopicStatus.learning,
        weak: ['s1', 's2'],
        done: ['s1'],
      ),
    ];
    const vocabWork = VocabPlan(
      level: 2,
      focusSubSkillIds: ['collocations', 'phrasal_verbs'],
      completedChunkIds: ['c_collocations'],
    );

    test('vocabulary when its plan is newer', () {
      final step = decide(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1', 's2'],
            done: ['s1'],
            at: older,
          ),
        ],
        plan: VocabPlan(
          level: 2,
          focusSubSkillIds: const ['collocations', 'phrasal_verbs'],
          completedChunkIds: const ['c_collocations'],
          updatedAt: newer,
        ),
        chunks: planChunks,
      );

      expect(step, isA<ContinueVocabulary>());
    });

    test('grammar when its topic is newer', () {
      final step = decide(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1', 's2'],
            done: ['s1'],
            at: newer,
          ),
        ],
        plan: VocabPlan(
          level: 2,
          focusSubSkillIds: const ['collocations', 'phrasal_verbs'],
          completedChunkIds: const ['c_collocations'],
          updatedAt: older,
        ),
        chunks: planChunks,
      );

      expect(step, isA<ContinueTopic>());
    });

    test('a cleared level never outranks a topic still being taught', () {
      // The state a device found: the post-check left one area weak, so
      // grammar is mid-flight, while the vocabulary level was cleared more
      // recently. Recency used to hand the hero to the level check, and the
      // screen then claimed the learner was all caught up.
      final step = decide(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1'],
            at: DateTime(2026, 9, 4, 10),
          ),
        ],
        plan: VocabPlan(
          level: 2,
          focusSubSkillIds: const [],
          updatedAt: DateTime(2026, 9, 4, 16),
        ),
      );

      expect(step, isA<StartTopicLearning>());
      expect(step.isWorkInProgress, isTrue);
    });

    test('grammar keeps unstamped progress, so an upgrade does not jump', () {
      final step = decide(
        progress: grammarWork,
        plan: vocabWork,
        chunks: planChunks,
      );

      expect(step, isA<ContinueTopic>());
    });
  });

  group('the rest of the screen', () {
    HomeState build({
      List<TopicProgress> progress = const [],
      VocabPlan? plan,
      List<VocabChunk> chunks = const [],
    }) => buildHomeState(
      topics: grammar,
      progress: progress,
      course: course,
      plan: plan,
      planChunks: chunks,
    );

    test('the losing section is still reachable as a row', () {
      final home = build(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1', 's2'],
            done: ['s1'],
          ),
        ],
        plan: const VocabPlan(
          level: 2,
          focusSubSkillIds: ['collocations', 'phrasal_verbs'],
          completedChunkIds: ['c_collocations'],
        ),
        chunks: planChunks,
      );

      expect(home.next, isA<ContinueTopic>());
      expect(home.alsoInProgress, isA<ContinueVocabulary>());
    });

    test('weak areas mix both sections and stop at three', () {
      final home = build(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1', 's2', 's3'],
          ),
        ],
        plan: const VocabPlan(
          level: 2,
          focusSubSkillIds: ['collocations', 'phrasal_verbs'],
        ),
        chunks: planChunks,
      );

      expect(home.weakAreas, hasLength(3));
      expect(home.weakAreas.map((a) => a.context), [
        'Present Simple',
        'Vocabulary Level 2',
        'Present Simple',
      ]);
      // Titles, never ids — an id on screen is a bug the learner sees.
      expect(home.weakAreas[1].title, 'Words that go together');
    });

    test('a practised area stops being a weakness', () {
      final home = build(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1', 's2'],
            done: ['s1'],
          ),
        ],
      );

      expect(home.weakAreas.map((a) => a.title), ['Sub-skill 2']);
    });

    test('a cleared level does not hide pending grammar work', () {
      final home = build(
        progress: [
          topic(
            'present_simple',
            status: TopicStatus.learning,
            weak: ['s1'],
            at: DateTime(2026, 9, 4, 10),
          ),
        ],
        plan: VocabPlan(
          level: 2,
          focusSubSkillIds: const [],
          updatedAt: DateTime(2026, 9, 4, 16),
        ),
      );

      expect(home.next, isA<StartTopicLearning>());
      // "Start something new" and the finished list stay away while a topic
      // is unfinished.
      expect(home.untouched, isEmpty);
      expect(home.finished, isEmpty);
      expect(home.weakAreas, hasLength(1));
    });

    test('a topic counts as started before it is finished', () {
      // The device case: a post-check left one area weak, so the topic is
      // not completed. Counting only completions showed 0 after a full
      // round of work.
      final home = build(
        progress: [
          topic('present_simple', status: TopicStatus.learning, weak: ['s1']),
        ],
      );

      expect(home.stats.topicsStarted, 1);
      expect(home.stats.topicsTotal, 2);
      expect(home.finished, isEmpty);
    });

    test('finished topics stay hidden while there is work in flight', () {
      final home = build(
        progress: [
          topic('present_simple', status: TopicStatus.completed),
          topic('articles', status: TopicStatus.tested, weak: ['s1']),
        ],
      );

      expect(home.next, isA<StartTopicLearning>());
      expect(home.finished, isEmpty);
      expect(home.untouched, isEmpty);
    });

    test('finished topics appear once nothing is pending', () {
      final home = build(
        progress: [topic('present_simple', status: TopicStatus.completed)],
      );

      expect(home.finished.map((t) => t.title), ['Present Simple']);
      // The hero already offers Articles, so the row does not repeat it.
      expect(home.next, isA<StartNewTopic>());
      expect(home.untouched, isEmpty);
    });

    test('the gain averages every re-checked topic, and is null with none', () {
      ScoreSnapshot score(int percent) => ScoreSnapshot(
        correct: percent,
        total: 100,
        percent: percent,
        takenAt: DateTime(2026, 9, 1),
        subSkills: const [],
      );

      final home = build(
        progress: [
          TopicProgress(
            topicId: 'present_simple',
            status: TopicStatus.completed,
            preAssessment: score(40),
            postAssessment: score(80),
          ),
          TopicProgress(
            topicId: 'articles',
            status: TopicStatus.completed,
            preAssessment: score(50),
            postAssessment: score(70),
          ),
        ],
      );

      expect(home.stats.grammarGain, 30);
      expect(home.stats.topicsStarted, 2);
      expect(home.stats.topicsTotal, 2);

      expect(build().stats.grammarGain, isNull);
      expect(build().stats.vocabLevel, isNull);
    });
  });
}
