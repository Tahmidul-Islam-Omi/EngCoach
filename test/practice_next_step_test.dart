import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/features/lesson/view/learning_path_screen.dart';
import 'package:engcoach/features/lesson/view/lesson_screen.dart';
import 'package:engcoach/features/practice/view/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

/// A real topic, because practice needs authored questions with feedback.
Topic realTopic() => topicFromFile('present_simple');

void main() {
  TopicProgress planOf({
    required List<String> weak,
    List<String> done = const [],
  }) => TopicProgress(
    topicId: 'present_simple',
    status: TopicStatus.learning,
    weakSubSkills: weak,
    completedSubSkills: done,
  );

  /// Runs a lesson's practice to the end and returns what the summary offers.
  Future<void> practiseThrough(
    WidgetTester tester, {
    required TopicProgress progress,
    required String subSkillId,
  }) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final topic = realTopic();
    final router = GoRouter(
      initialLocation: '/topic/present_simple/learn',
      routes: [
        GoRoute(
          path: '/topic/:topicId/learn',
          builder: (_, s) =>
              LearningPathScreen(topicId: s.pathParameters['topicId']!),
        ),
        GoRoute(
          path: '/topic/:topicId/lesson/:subSkillId',
          builder: (_, s) => LessonScreen(
            topicId: s.pathParameters['topicId']!,
            subSkillId: s.pathParameters['subSkillId']!,
          ),
        ),
        GoRoute(
          path: '/topic/:topicId/practice/:subSkillId',
          builder: (_, s) => PracticeScreen(
            topicId: s.pathParameters['topicId']!,
            subSkillId: s.pathParameters['subSkillId']!,
          ),
        ),
        GoRoute(
          path: '/topic/:topicId/final-check',
          builder: (_, _) => const Scaffold(body: Text('the final check')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(
            FakeContentRepository(topic),
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(progress),
          ),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/topic/present_simple/lesson/$subSkillId');
    await tester.pumpAndSettle();
    router.push('/topic/present_simple/practice/$subSkillId');
    await tester.pumpAndSettle();

    // Three questions, answered any way — completion does not depend on
    // getting them right.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('offers the next lesson when the plan has more', (tester) async {
    final topic = realTopic();
    final first = topic.subSkills[0].id;
    final second = topic.subSkills[1].id;

    await practiseThrough(
      tester,
      progress: planOf(weak: [first, second]),
      subSkillId: first,
    );

    expect(find.text('Next lesson'), findsOneWidget);
    expect(find.text('Take the final check'), findsNothing);
  });

  testWidgets('offers the final check when nothing is left', (tester) async {
    // The whole point: three taps and a scroll used to stand between
    // finishing the last practice and the check that measures it.
    final topic = realTopic();
    final only = topic.subSkills.first.id;

    await practiseThrough(
      tester,
      progress: planOf(weak: [only]),
      subSkillId: only,
    );

    expect(find.text('Take the final check'), findsOneWidget);

    await tester.tap(find.text('Take the final check'));
    await tester.pumpAndSettle();

    expect(find.text('the final check'), findsOneWidget);
  });

  testWidgets('ignores lessons already finished', (tester) async {
    final topic = realTopic();
    final a = topic.subSkills[0].id;
    final b = topic.subSkills[1].id;

    await practiseThrough(
      tester,
      progress: planOf(weak: [a, b], done: [b]),
      subSkillId: a,
    );

    expect(find.text('Take the final check'), findsOneWidget);
  });

  testWidgets('going back from the next lesson lands on the plan', (
    tester,
  ) async {
    final topic = realTopic();
    final first = topic.subSkills[0].id;
    final second = topic.subSkills[1].id;

    await practiseThrough(
      tester,
      progress: planOf(weak: [first, second]),
      subSkillId: first,
    );
    await tester.tap(find.text('Next lesson'));
    await tester.pumpAndSettle();

    // The lesson just read must not be sitting underneath.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('YOUR LESSONS'), findsOneWidget);
  });
}
