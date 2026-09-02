import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/features/lesson/view/learning_path_screen.dart';
import 'package:engcoach/features/lesson/view/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/topic_fixture.dart';

void main() {
  TopicProgress progressWith(
    List<String> weak, {
    List<String> done = const [],
    TopicStatus status = TopicStatus.tested,
  }) => TopicProgress(
    topicId: 'test_topic',
    status: status,
    weakSubSkills: weak,
    completedSubSkills: done,
  );

  Future<void> pumpPath(
    WidgetTester tester, {
    required Topic topic,
    required TopicProgress? progress,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/topic/test_topic/learn',
      routes: [
        GoRoute(
          path: '/topic/:topicId/learn',
          builder: (_, state) =>
              LearningPathScreen(topicId: state.pathParameters['topicId']!),
        ),
        GoRoute(
          path: '/topic/:topicId/lesson/:subSkillId',
          builder: (_, state) => LessonScreen(
            topicId: state.pathParameters['topicId']!,
            subSkillId: state.pathParameters['subSkillId']!,
          ),
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
  }

  group('the plan', () {
    testWidgets('lists only the sub-skills the check flagged', (tester) async {
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 4),
        progress: progressWith(['s2', 's4']),
      );

      expect(find.text('Sub-skill 2'), findsOneWidget);
      expect(find.text('Sub-skill 4'), findsOneWidget);
      expect(find.text('Sub-skill 1'), findsNothing);
      expect(find.text('Sub-skill 3'), findsNothing);
      // The plan names what to work on; how many were skipped is internal
      // accounting the learner has no use for.
      expect(find.textContaining('parts to work on'), findsOneWidget);
      expect(find.textContaining('you can skip'), findsNothing);
    });

    testWidgets('keeps authored order, not the stored order', (tester) async {
      // Teaching order is the content's, so a stored list in another order
      // must not reorder the plan.
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 3),
        progress: progressWith(['s3', 's1']),
      );

      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => s.startsWith('Sub-skill'))
          .toList();

      expect(titles, ['Sub-skill 1', 'Sub-skill 3']);
    });

    testWidgets('drops a sub-skill the content no longer has', (tester) async {
      // Stored progress can outlive a content edit.
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 2),
        progress: progressWith(['s1', 'removed_last_year']),
      );

      expect(find.text('Sub-skill 1'), findsOneWidget);
    });

    testWidgets('asks for the check when there is no progress', (tester) async {
      await pumpPath(tester, topic: buildTopic(), progress: null);

      expect(find.text('Take the check first.'), findsOneWidget);
    });

    testWidgets('says so when nothing was flagged', (tester) async {
      await pumpPath(
        tester,
        topic: buildTopic(),
        progress: progressWith(const []),
      );

      expect(find.text('Nothing to study here.'), findsOneWidget);
    });

    testWidgets('ticks off what has been practised', (tester) async {
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 3),
        progress: progressWith(['s1', 's2', 's3'], done: ['s1', 's3']),
      );

      expect(find.text('2 of 3 done'), findsOneWidget);
      // A number becomes a tick; the unfinished one keeps its number.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('counts only plan sub-skills as done', (tester) async {
      // Completed work on a sub-skill that is not in the plan must not
      // inflate the count.
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 3),
        progress: progressWith(['s1'], done: ['s1', 's2']),
      );

      expect(find.text('1 of 1 done'), findsOneWidget);
    });

    testWidgets('a finished lesson is still openable', (tester) async {
      // Going back over a lesson is exactly what someone should be able
      // to do.
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 2),
        progress: progressWith(['s1'], done: ['s1']),
      );

      await tester.tap(find.text('Sub-skill 1'));
      await tester.pumpAndSettle();

      expect(find.text('LESSON 1 OF 1'), findsOneWidget);
    });

    testWidgets('opens the lesson it points at', (tester) async {
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 3),
        progress: progressWith(['s2', 's3']),
      );

      await tester.tap(find.text('Sub-skill 2'));
      await tester.pumpAndSettle();

      expect(find.text('LESSON 1 OF 2'), findsOneWidget);
    });
  });

  group('moving through the plan', () {
    testWidgets('the last lesson offers no next', (tester) async {
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 3),
        progress: progressWith(['s1', 's3']),
      );
      await tester.tap(find.text('Sub-skill 3'));
      await tester.pumpAndSettle();

      expect(find.text('LESSON 2 OF 2'), findsOneWidget);
      expect(find.text('Done for now'), findsOneWidget);
      expect(find.text('Next lesson'), findsNothing);
    });

    testWidgets('advances to the next lesson in the plan', (tester) async {
      await pumpPath(
        tester,
        topic: buildTopic(subSkills: 3),
        progress: progressWith(['s1', 's3']),
      );
      await tester.tap(find.text('Sub-skill 1'));
      await tester.pumpAndSettle();
      expect(find.text('Next lesson'), findsOneWidget);

      await tester.tap(find.text('Next lesson'));
      await tester.pumpAndSettle();

      expect(find.text('LESSON 2 OF 2'), findsOneWidget);
      expect(find.text('Lesson for Sub-skill 3'), findsOneWidget);
    });
  });
}
