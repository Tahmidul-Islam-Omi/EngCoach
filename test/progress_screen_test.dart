import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/progress/view/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/topic_fixture.dart';

void main() {
  final topics = [
    buildTopic(id: 'present_simple', title: 'Present Simple', subSkills: 5),
    buildTopic(id: 'articles', title: 'Articles', subSkills: 6),
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

  late GoRouter router;
  String opened() => router.state.uri.toString();

  Future<void> pumpProgress(
    WidgetTester tester, {
    List<TopicProgress> progress = const [],
    VocabPlan? plan,
    Duration planDelay = Duration.zero,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget stub(String name) => Scaffold(body: Text('opened $name'));

    router = GoRouter(
      initialLocation: Routes.progress,
      routes: [
        GoRoute(
          path: Routes.progress,
          builder: (_, _) => const ProgressScreen(),
        ),
        GoRoute(path: Routes.grammar, builder: (_, _) => stub('grammar')),
        GoRoute(path: '/topic/:id', builder: (_, _) => stub('topic')),
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
          vocabProgressRepositoryProvider.overrideWithValue(
            FakeVocabProgressRepository(plan, planDelay),
          ),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

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
    ScoreSnapshot? pre,
    ScoreSnapshot? post,
  }) => TopicProgress(
    topicId: id,
    status: status,
    weakSubSkills: weak,
    preAssessment: pre,
    postAssessment: post,
  );

  testWidgets('one check is a starting point, not a result', (tester) async {
    await pumpProgress(
      tester,
      progress: [
        progressFor('present_simple', weak: ['s1', 's2'], pre: score(60)),
      ],
    );

    expect(find.text('No before and after yet'), findsOneWidget);
    // The 60% must not be dressed up as an outcome.
    expect(find.text('YOU IMPROVED'), findsNothing);
    expect(find.text('Before'), findsNothing);

    // It is still reported, as one bar.
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('2 of 5 parts came back weak.'), findsOneWidget);
  });

  testWidgets('the headline card averages the re-checked topics', (
    tester,
  ) async {
    await pumpProgress(
      tester,
      progress: [
        progressFor('present_simple', pre: score(60), post: score(80)),
        progressFor('articles', pre: score(45), post: score(60)),
      ],
    );

    expect(find.text('YOU IMPROVED'), findsOneWidget);
    expect(find.text('53%'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(
      find.text(
        'Across 2 re-checked topics, on the same rules asked differently.',
      ),
      findsOneWidget,
    );

    // Weakest first, so Articles leads.
    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(
      titles.indexOf('Articles'),
      lessThan(titles.indexOf('Present Simple')),
    );
    expect(find.text('+15'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
  });

  testWidgets('vocabulary shows counts, never percentages', (tester) async {
    await pumpProgress(
      tester,
      plan: const VocabPlan(
        level: 2,
        focusSubSkillIds: [],
        before: [
          VocabSubSkillScore(subSkillId: 'collocations', correct: 0, total: 1),
          VocabSubSkillScore(subSkillId: 'phrasal_verbs', correct: 0, total: 1),
        ],
        after: [
          VocabSubSkillScore(subSkillId: 'collocations', correct: 3, total: 3),
          VocabSubSkillScore(subSkillId: 'phrasal_verbs', correct: 2, total: 3),
        ],
      ),
    );

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Words that go together'), findsOneWidget);
    expect(find.text('0/1'), findsNWidgets(2));
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);

    // The bug this guards: one question rendered as 0% and 100%.
    expect(find.text('0%'), findsNothing);
    expect(find.text('100%'), findsNothing);
  });

  testWidgets('every weak area is listed and opens its lesson', (tester) async {
    await pumpProgress(
      tester,
      progress: [
        progressFor(
          'present_simple',
          weak: ['s1', 's2', 's3', 's4'],
          pre: score(40),
        ),
      ],
    );

    // Home caps at three; the profile does not.
    expect(find.text('STILL TO WORK ON · 4'), findsOneWidget);
    expect(find.text('Sub-skill 4'), findsOneWidget);

    await tester.tap(find.text('Sub-skill 4'));
    await tester.pumpAndSettle();
    expect(opened(), '/topic/present_simple/lesson/s4');
  });

  testWidgets('the check list is dated, newest first', (tester) async {
    await pumpProgress(
      tester,
      progress: [
        progressFor(
          'present_simple',
          pre: score(60, at: DateTime(2026, 8, 21)),
          post: score(80, at: DateTime(2026, 9, 2)),
        ),
      ],
    );

    expect(find.text('EVERY CHECK YOU HAVE TAKEN'), findsOneWidget);
    expect(find.text('Present Simple — second check'), findsOneWidget);
    expect(find.text('80%, up 20 points'), findsOneWidget);
    expect(find.text('2 Sep'), findsOneWidget);
    expect(find.text('21 Aug'), findsOneWidget);
  });

  testWidgets('a slow read shows a spinner, not an empty report', (
    tester,
  ) async {
    await pumpProgress(
      tester,
      planDelay: const Duration(milliseconds: 200),
      settle: false,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No before and after yet'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('No before and after yet'), findsOneWidget);
  });
}
