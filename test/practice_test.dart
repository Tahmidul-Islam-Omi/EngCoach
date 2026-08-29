import 'dart:convert';
import 'dart:io';

import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/features/practice/model/practice_state.dart';
import 'package:engcoach/features/practice/view/practice_screen.dart';
import 'package:engcoach/features/practice/viewmodel/practice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';




/// A real authored topic — practice questions carry feedback in two
/// languages, which no fixture would reproduce faithfully.
Topic realTopic([String name = 'present_simple']) => Topic.fromJson(
      jsonDecode(File('content/grammar/$name.json').readAsStringSync())
          as Map<String, dynamic>,
    );

void main() {
  group('the view model', () {
    late Topic topic;
    late FakeProgressRepository progress;

    PracticeKey keyFor(Topic t) =>
        (topicId: t.id, subSkillId: t.subSkills.first.id);

    Future<ProviderContainer> started(Topic t) async {
      final c = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository(t)),
          progressRepositoryProvider.overrideWithValue(progress),
        ],
      );
      addTearDown(c.dispose);
      c.read(practiceViewModelProvider(keyFor(t)));
      await c.read(topicProvider(t.id).future);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    setUp(() {
      topic = realTopic();
      progress = FakeProgressRepository();
    });

    test('loads the lesson\'s questions', () async {
      final c = await started(topic);
      final state = c.read(practiceViewModelProvider(keyFor(topic)));

      expect(state.status, PracticeStatus.inProgress);
      expect(state.total, 3);
      expect(state.revealed, isFalse);
    });

    test('choosing reveals, and choosing again is ignored', () async {
      final c = await started(topic);
      final key = keyFor(topic);
      final model = c.read(practiceViewModelProvider(key).notifier);
      final item = c.read(practiceViewModelProvider(key)).current!;

      final wrong = item.options.firstWhere((o) => !o.correct).id;
      model.choose(wrong);
      expect(c.read(practiceViewModelProvider(key)).revealed, isTrue);
      expect(c.read(practiceViewModelProvider(key)).isCorrect, isFalse);

      // Switching after seeing the explanation would be guessing.
      model.choose(item.correctOptionId);
      expect(c.read(practiceViewModelProvider(key)).chosenOptionId, wrong);
    });

    test('cannot move on before answering', () async {
      final c = await started(topic);
      final key = keyFor(topic);

      c.read(practiceViewModelProvider(key).notifier).next();

      expect(c.read(practiceViewModelProvider(key)).index, 0);
    });

    test('counts what was right across the set', () async {
      final c = await started(topic);
      final key = keyFor(topic);
      final model = c.read(practiceViewModelProvider(key).notifier);

      for (var i = 0; i < 3; i++) {
        final item = c.read(practiceViewModelProvider(key)).current!;
        // Right, wrong, right.
        model.choose(i == 1
            ? item.options.firstWhere((o) => !o.correct).id
            : item.correctOptionId);
        model.next();
      }

      final state = c.read(practiceViewModelProvider(key));
      expect(state.status, PracticeStatus.finished);
      expect(state.correctCount, 2);
      expect(state.total, 3);
    });

    test('finishing marks the sub-skill complete', () async {
      final c = await started(topic);
      final key = keyFor(topic);
      final model = c.read(practiceViewModelProvider(key).notifier);

      for (var i = 0; i < 3; i++) {
        model.choose(
          c.read(practiceViewModelProvider(key)).current!.correctOptionId,
        );
        model.next();
      }
      await Future<void>.delayed(Duration.zero);

      expect(progress.completed, [key.subSkillId]);
    });

    test('stopping part way marks nothing', () async {
      // Reading and answering one question is not finishing the practice.
      final c = await started(topic);
      final key = keyFor(topic);
      final model = c.read(practiceViewModelProvider(key).notifier);

      model.choose(
        c.read(practiceViewModelProvider(key)).current!.correctOptionId,
      );
      model.next();
      await Future<void>.delayed(Duration.zero);

      expect(progress.completed, isEmpty);
    });

    test('a wrong answer still counts as having practised', () async {
      // Completion means they did the work, not that they got it all right.
      final c = await started(topic);
      final key = keyFor(topic);
      final model = c.read(practiceViewModelProvider(key).notifier);

      for (var i = 0; i < 3; i++) {
        final item = c.read(practiceViewModelProvider(key)).current!;
        model.choose(item.options.firstWhere((o) => !o.correct).id);
        model.next();
      }
      await Future<void>.delayed(Duration.zero);

      expect(progress.completed, [key.subSkillId]);
      expect(c.read(practiceViewModelProvider(key)).correctCount, 0);
    });

    test('a restart clears the answers', () async {
      final c = await started(topic);
      final key = keyFor(topic);
      final model = c.read(practiceViewModelProvider(key).notifier);

      model.choose(c.read(practiceViewModelProvider(key)).current!.correctOptionId);
      model.restart();

      final state = c.read(practiceViewModelProvider(key));
      expect(state.revealed, isFalse);
      expect(state.answers, isEmpty);
      expect(state.index, 0);
    });

    test('does not reorder the topic it drew from', () async {
      // Content is parsed once and cached; shuffling in place would scramble
      // the options for every later visit.
      final before = topic.lessons.first.practice
          .map((q) => q.options.map((o) => o.id).join())
          .toList();
      await started(topic);
      final after = topic.lessons.first.practice
          .map((q) => q.options.map((o) => o.id).join())
          .toList();

      expect(after, before);
    });
  });

  group('the screen', () {
    Future<void> pumpPractice(WidgetTester tester, Topic topic) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/practice',
        routes: [
          GoRoute(
            path: '/practice',
            builder: (_, _) => PracticeScreen(
              topicId: topic.id,
              subSkillId: topic.subSkills.first.id,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(FakeContentRepository(topic)),
          ],
          child:
              MaterialApp.router(routerConfig: router, theme: AppTheme.light),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows nothing until an answer is chosen', (tester) async {
      await pumpPractice(tester, realTopic());

      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('THAT’S RIGHT'), findsNothing);
      expect(find.text('NOT QUITE'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a wrong answer explains itself in both languages',
        (tester) async {
      final topic = realTopic();
      await pumpPractice(tester, topic);

      // Tap the first option that is not the answer.
      final question = topic.lessons.first.practice.first;
      final wrong = question.options.firstWhere((o) => !o.correct);
      await tester.tap(find.text(wrong.text.replaceAll('**', '')));
      await tester.pumpAndSettle();

      expect(find.text('NOT QUITE'), findsOneWidget);
      // The authored English and Bangla, with markup resolved.
      expect(
        find.text(wrong.feedback!.en.replaceAll('*', '')),
        findsOneWidget,
      );
      expect(
        find.text(wrong.feedback!.bn.replaceAll('*', '')),
        findsOneWidget,
      );
    });

    testWidgets('answering unlocks moving on', (tester) async {
      final topic = realTopic();
      await pumpPractice(tester, topic);

      final answer = topic.lessons.first.practice.first.correctOption;
      await tester.tap(find.text(answer.text.replaceAll('**', '')));
      await tester.pumpAndSettle();

      expect(find.text('THAT’S RIGHT'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  });

  group('every authored practice set', () {
    final files = Directory('content')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final name = file.path.split('/').last.replaceAll('.json', '');

      test('$name has practice with feedback on every option', () {
        final topic = Topic.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );

        for (final lesson in topic.lessons) {
          expect(lesson.practice, isNotEmpty, reason: lesson.id);
          for (final q in lesson.practice) {
            expect(q.options.where((o) => o.correct), hasLength(1),
                reason: q.id);
            for (final o in q.options) {
              // The practice screen shows the chosen option's explanation —
              // an option without one would reveal an empty box.
              expect(o.feedback, isNotNull, reason: '${q.id} / ${o.id}');
              expect(o.feedback!.bn, isNotEmpty, reason: '${q.id} / ${o.id}');
            }
          }
        }
      });
    }
  });
}
