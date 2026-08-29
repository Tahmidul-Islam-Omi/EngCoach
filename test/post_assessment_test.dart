import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/assessment_paper.dart';
import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/features/assessment/view/assessment_screen.dart';
import 'package:engcoach/features/assessment/viewmodel/assessment_view_model.dart';
import 'package:engcoach/features/lesson/view/learning_path_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/topic_fixture.dart';


void main() {
  TopicProgress progressWith({
    required List<String> weak,
    required List<String> done,
    int? prePercent,
  }) =>
      TopicProgress(
        topicId: 'test_topic',
        status: TopicStatus.learning,
        weakSubSkills: weak,
        completedSubSkills: done,
        preAssessment: prePercent == null
            ? null
            : ScoreSnapshot(
                correct: prePercent ~/ 10,
                total: 10,
                percent: prePercent,
                takenAt: DateTime(2026, 8, 29),
                subSkills: const [],
              ),
      );

  group('the view model', () {
    test('draws from the post bank, not the pre one', () async {
      final topic = buildTopic();
      final c = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository(topic)),
          progressRepositoryProvider
              .overrideWithValue(FakeProgressRepository(null)),
        ],
      );
      addTearDown(c.dispose);

      const key = (topicId: 'test_topic', phase: AssessmentPhase.post);
      c.read(assessmentViewModelProvider(key));
      await c.read(topicProvider('test_topic').future);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(assessmentViewModelProvider(key));
      expect(state.paper!.phase, AssessmentPhase.post);
      expect(
        state.paper!.questions.every((q) => q.id.contains('-post-')),
        isTrue,
        reason: 'a repeat of the pre questions would measure memory',
      );
    });

    test('the two phases are separate flows', () async {
      // Answering the pre-assessment must not carry into the post one.
      final topic = buildTopic();
      final c = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository(topic)),
          progressRepositoryProvider
              .overrideWithValue(FakeProgressRepository(null)),
        ],
      );
      addTearDown(c.dispose);

      const pre = (topicId: 'test_topic', phase: AssessmentPhase.pre);
      const post = (topicId: 'test_topic', phase: AssessmentPhase.post);
      c.read(assessmentViewModelProvider(pre));
      c.read(assessmentViewModelProvider(post));
      await c.read(topicProvider('test_topic').future);
      await Future<void>.delayed(Duration.zero);

      final model = c.read(assessmentViewModelProvider(pre).notifier);
      model.select(c.read(assessmentViewModelProvider(pre)).current!.correctOptionId);

      expect(c.read(assessmentViewModelProvider(pre)).answers, hasLength(1));
      expect(c.read(assessmentViewModelProvider(post)).answers, isEmpty);
    });
  });

  group('the plan', () {
    Future<void> pumpPath(
      WidgetTester tester, {
      required TopicProgress progress,
    }) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final topic = buildTopic(subSkills: 3);
      final router = GoRouter(
        initialLocation: '/topic/test_topic/learn',
        routes: [
          GoRoute(
            path: '/topic/:topicId/learn',
            builder: (_, state) => LearningPathScreen(
              topicId: state.pathParameters['topicId']!,
            ),
          ),
          GoRoute(
            path: '/topic/:topicId/final-check',
            builder: (_, state) => AssessmentScreen(
              topicId: state.pathParameters['topicId']!,
              phase: AssessmentPhase.post,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(FakeContentRepository(topic)),
            progressRepositoryProvider
                .overrideWithValue(FakeProgressRepository(progress)),
          ],
          child:
              MaterialApp.router(routerConfig: router, theme: AppTheme.light),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers the final check only when every lesson is done',
        (tester) async {
      await pumpPath(
        tester,
        progress: progressWith(weak: ['s1', 's2'], done: ['s1']),
      );

      expect(find.text('Take the final check'), findsNothing);
    });

    testWidgets('offers it once they are all done', (tester) async {
      await pumpPath(
        tester,
        progress: progressWith(weak: ['s1', 's2'], done: ['s1', 's2']),
      );

      expect(find.text('Take the final check'), findsOneWidget);
      expect(find.text('Now see how much changed.'), findsOneWidget);
    });

    testWidgets('starts the post-assessment', (tester) async {
      await pumpPath(
        tester,
        progress: progressWith(weak: ['s1'], done: ['s1']),
      );

      await tester.tap(find.text('Take the final check'));
      await tester.pumpAndSettle();

      expect(find.text('Final check'), findsOneWidget);
      expect(find.text('Question 1 of 9'), findsOneWidget);
    });
  });
}
