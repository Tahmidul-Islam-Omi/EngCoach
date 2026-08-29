import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/assessment_result.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/models/topic_status.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/features/grammar/view/grammar_topics_screen.dart';
import 'package:engcoach/features/grammar/view/topic_overview_screen.dart';
import 'package:engcoach/features/lesson/view/learning_path_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/topic_fixture.dart';

class _StubContent implements ContentRepository {
  _StubContent(this.topic);

  final Topic topic;

  @override
  Future<Topic> topicById(String id) async => topic;

  @override
  Future<List<Topic>> topicsForSection(String section) async => [topic];
}

class _StubProgress implements ProgressRepository {
  _StubProgress(this.progress);

  final TopicProgress? progress;

  @override
  Future<TopicProgress?> topicProgress(String topicId) async => progress;

  @override
  Future<void> saveAssessment(AssessmentResult result) async {}

  @override
  Future<void> markSubSkillComplete({
    required String topicId,
    required String subSkillId,
  }) async {}

  @override
  Future<void> touch() async {}
}

void main() {
  final topic = buildTopic(subSkills: 3);

  Future<void> pump(
    WidgetTester tester, {
    required String at,
    TopicProgress? progress,
  }) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(
          path: '/topics',
          builder: (_, _) => const GrammarTopicsScreen(),
        ),
        GoRoute(
          path: '/topic/:topicId',
          builder: (_, state) => TopicOverviewScreen(
            topicId: state.pathParameters['topicId']!,
          ),
        ),
        GoRoute(
          path: '/topic/:topicId/learn',
          builder: (_, state) => LearningPathScreen(
            topicId: state.pathParameters['topicId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_StubContent(topic)),
          progressRepositoryProvider.overrideWithValue(_StubProgress(progress)),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('coming back to a topic', () {
    testWidgets('a fresh topic invites the check', (tester) async {
      await pump(tester, at: '/topic/test_topic');

      expect(find.text('Start with a quick check'), findsOneWidget);
      expect(find.textContaining('Continue learning'), findsNothing);
    });

    testWidgets('a checked topic offers the plan instead', (tester) async {
      // Without this there was no route back to a half-finished topic at
      // all — the only way in was to retake the check.
      await pump(
        tester,
        at: '/topic/test_topic',
        progress: const TopicProgress(
          topicId: 'test_topic',
          status: TopicStatus.learning,
          weakSubSkills: ['s1', 's2'],
          completedSubSkills: ['s1'],
        ),
      );

      expect(find.text('Continue learning · 1 of 2 done'), findsOneWidget);
      expect(find.text('Take the check again'), findsOneWidget);
      expect(find.text('Start with a quick check'), findsNothing);
    });

    testWidgets('the plan is one tap away', (tester) async {
      await pump(
        tester,
        at: '/topic/test_topic',
        progress: const TopicProgress(
          topicId: 'test_topic',
          status: TopicStatus.tested,
          weakSubSkills: ['s2'],
        ),
      );

      await tester.tap(find.textContaining('Continue learning'));
      await tester.pumpAndSettle();

      expect(find.text('YOUR LESSONS'), findsOneWidget);
    });

    testWidgets('a topic that came back clear says so', (tester) async {
      await pump(
        tester,
        at: '/topic/test_topic',
        progress: const TopicProgress(
          topicId: 'test_topic',
          status: TopicStatus.tested,
        ),
      );

      expect(find.text('See your result'), findsOneWidget);
    });
  });

  group('the topic list', () {
    testWidgets('suggests the first topic while it is untouched',
        (tester) async {
      await pump(tester, at: '/topics');

      expect(find.text('START HERE'), findsOneWidget);
    });

    testWidgets('shows the stored status', (tester) async {
      // It used to be hardcoded, so a topic stayed Not Started forever no
      // matter how much of it the learner had done.
      await pump(
        tester,
        at: '/topics',
        progress: const TopicProgress(
          topicId: 'test_topic',
          status: TopicStatus.learning,
        ),
      );

      expect(find.text('LEARNING'), findsOneWidget);
      // The suggestion steps aside — it used to hide the status entirely.
      expect(find.text('START HERE'), findsNothing);
    });
  });
}
