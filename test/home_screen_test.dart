import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/models/vocabulary/vocab_chunk.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_level.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/home/view/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/topic_fixture.dart';

void main() {
  final topics = [
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

  const level2 = VocabLevel(
    level: 2,
    title: 'Developing',
    summary: 'For tests.',
    subSkills: [],
    chunks: [
      VocabChunk(
        id: 'c_collocations',
        subSkillId: 'collocations',
        title: 'Verbs that choose their partners',
        words: [],
        practice: [],
      ),
      VocabChunk(
        id: 'c_phrasal',
        subSkillId: 'phrasal_verbs',
        title: 'Phrasal verbs you will hear at work',
        words: [],
        practice: [],
      ),
    ],
  );

  /// The live router, so navigation is asserted on rather than assumed.
  late GoRouter router;

  String opened() => router.state.uri.toString();

  Future<void> pumpHome(
    WidgetTester tester, {
    List<TopicProgress> progress = const [],
    VocabPlan? plan,
    Duration planDelay = Duration.zero,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget stub(String name) => Scaffold(body: Text('opened $name'));

    router = GoRouter(
      initialLocation: Routes.home,
      routes: [
        GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
        GoRoute(path: Routes.learn, builder: (_, _) => stub('learn')),
        GoRoute(path: Routes.grammar, builder: (_, _) => stub('grammar')),
        GoRoute(
          path: Routes.vocabularyCheck,
          builder: (_, _) => stub('vocab check'),
        ),
        GoRoute(
          path: '/vocabulary/learn/:chunkId',
          builder: (_, _) => stub('word set'),
        ),
        GoRoute(path: '/topic/:id/learn', builder: (_, _) => stub('path')),
        GoRoute(
          path: '/topic/:id/lesson/:subSkillId',
          builder: (_, _) => stub('lesson'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sectionTopicsProvider('grammar').overrideWith((_) async => topics),
          allTopicProgressProvider.overrideWith((_) async => progress),
          vocabCourseProvider.overrideWith((_) async => course),
          vocabLevelProvider(2).overrideWith((_) async => level2),
          vocabProgressRepositoryProvider.overrideWithValue(
            FakeVocabProgressRepository(plan, planDelay),
          ),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  TopicProgress progressFor(
    String id, {
    required TopicStatus status,
    List<String> weak = const [],
    List<String> done = const [],
  }) => TopicProgress(
    topicId: id,
    status: status,
    weakSubSkills: weak,
    completedSubSkills: done,
  );

  testWidgets('a learner with no history is told how it works', (tester) async {
    await pumpHome(tester);

    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('Ready to learn your first topic?'), findsOneWidget);

    // The three steps, and the Bangla reassurance that there is no long
    // entry test.
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Learn & practise'), findsOneWidget);
    expect(find.text('See progress'), findsOneWidget);
    expect(find.textContaining('চেক'), findsOneWidget);

    // Nothing measured yet, so nothing is claimed.
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('the hero names the topic and the area coming next', (
    tester,
  ) async {
    await pumpHome(
      tester,
      progress: [
        progressFor(
          'present_simple',
          status: TopicStatus.learning,
          weak: ['s1', 's2', 's3'],
          done: ['s1'],
        ),
      ],
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('You left off in Present Simple.'), findsOneWidget);
    // Once as the hero's title, then again under each weak area it owns.
    expect(find.text('Present Simple'), findsWidgets);
    expect(
      find.text('1 of 3 areas done · next up “Sub-skill 2”'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('both sections are reachable, and weak areas mix', (
    tester,
  ) async {
    await pumpHome(
      tester,
      progress: [
        progressFor(
          'present_simple',
          status: TopicStatus.learning,
          weak: ['s1', 's2'],
          done: const [],
        ),
      ],
      plan: const VocabPlan(
        level: 2,
        focusSubSkillIds: ['collocations', 'phrasal_verbs'],
      ),
    );

    // Grammar took the hero; vocabulary is one row below rather than lost.
    expect(find.text('ALSO IN PROGRESS'), findsOneWidget);
    expect(find.text('Vocabulary · Level 2'), findsOneWidget);

    expect(find.text('YOUR WEAK AREAS'), findsOneWidget);
    expect(find.text('Sub-skill 1'), findsOneWidget);
    expect(find.text('Words that go together'), findsOneWidget);
    // Capped at three, so the fourth outstanding area is not listed.
    expect(find.text('Phrasal verbs'), findsNothing);
  });

  testWidgets('a weak area opens its own lesson', (tester) async {
    await pumpHome(
      tester,
      progress: [
        progressFor(
          'present_simple',
          status: TopicStatus.learning,
          weak: ['s1'],
        ),
      ],
    );

    await tester.tap(find.text('Sub-skill 1'));
    await tester.pumpAndSettle();

    expect(opened(), '/topic/present_simple/lesson/s1');
  });

  testWidgets('a cleared level offers the next one, not a dead end', (
    tester,
  ) async {
    await pumpHome(
      tester,
      progress: [
        progressFor('present_simple', status: TopicStatus.completed),
        progressFor('articles', status: TopicStatus.completed),
      ],
      plan: const VocabPlan(level: 2, focusSubSkillIds: []),
    );

    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('Check your vocabulary level again'), findsOneWidget);

    // Finished work is shown only now that nothing is pending.
    expect(find.text('FINISHED'), findsOneWidget);
    expect(find.text('Present Simple'), findsOneWidget);
    expect(find.text('Articles'), findsOneWidget);
    expect(find.text('Completed'), findsNWidgets(2));

    await tester.tap(find.text('Start the check'));
    await tester.pumpAndSettle();
    expect(opened(), Routes.vocabularyCheck);
  });

  testWidgets('a slow read shows a spinner, not an empty screen', (
    tester,
  ) async {
    await pumpHome(
      tester,
      planDelay: const Duration(milliseconds: 200),
      settle: false,
    );
    await tester.pump();

    // The bug this guards: treating "still loading" as "nothing to do" and
    // telling a learner with work waiting that they are all caught up.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Start here'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Start here'), findsOneWidget);
  });
}
