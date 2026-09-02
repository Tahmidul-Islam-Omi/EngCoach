import 'dart:convert';
import 'dart:io';

import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/features/lesson/view/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/topic_fixture.dart';

void main() {
  Future<GoRouter> pumpLesson(
    WidgetTester tester, {
    required Topic topic,
    required String subSkillId,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('topic overview')),
          routes: [
            GoRoute(
              path: 'lesson/:subSkillId',
              builder: (_, state) => LessonScreen(
                topicId: topic.id,
                subSkillId: state.pathParameters['subSkillId']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(
            FakeContentRepository(topic),
          ),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/lesson/$subSkillId');
    await tester.pumpAndSettle();
    return router;
  }

  group('the lesson screen', () {
    testWidgets('shows the lesson for the sub-skill it was asked for', (
      tester,
    ) async {
      final topic = buildTopic(subSkills: 3);
      await pumpLesson(tester, topic: topic, subSkillId: 's2');

      expect(find.text('Lesson for Sub-skill 2'), findsOneWidget);
      expect(find.text('Lesson for Sub-skill 1'), findsNothing);
    });

    testWidgets('says so when a sub-skill has no lesson', (tester) async {
      // A content fault must read as a message, not a crash.
      final topic = buildTopic(subSkills: 2);
      await pumpLesson(tester, topic: topic, subSkillId: 'not_authored');

      expect(find.text("This lesson isn't ready yet."), findsOneWidget);
    });

    testWidgets('leaves by the footer', (tester) async {
      final topic = buildTopic();
      await pumpLesson(tester, topic: topic, subSkillId: 's1');

      await tester.tap(find.text('Done for now'));
      await tester.pumpAndSettle();

      expect(find.text('topic overview'), findsOneWidget);
    });
  });

  group('real content', () {
    final files =
        Directory('content/grammar')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final name = file.path.split('/').last.replaceAll('.json', '');

      testWidgets('$name opens every lesson without overflowing', (
        tester,
      ) async {
        final topic = Topic.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );

        for (final subSkill in topic.subSkills) {
          await pumpLesson(tester, topic: topic, subSkillId: subSkill.id);

          expect(
            find.text(topic.lessonFor(subSkill.id).title),
            findsOneWidget,
            reason: '${subSkill.id} did not show its title',
          );
          expect(
            find.text("This lesson isn't ready yet."),
            findsNothing,
            reason: '${subSkill.id} has no authored lesson',
          );
        }
      });
    }
  });
}
