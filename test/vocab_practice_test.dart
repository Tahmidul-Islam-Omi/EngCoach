import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_ladder.dart';
import 'package:engcoach/data/models/vocabulary/vocab_paper.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/model/vocab_practice_state.dart';
import 'package:engcoach/features/vocabulary/view/vocab_path_screen.dart';
import 'package:engcoach/features/vocabulary/view/vocab_practice_screen.dart';
import 'package:engcoach/features/vocabulary/view/vocab_words_screen.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_plan_view_model.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_practice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/vocabulary_fixture.dart';

void main() {
  final course = VocabCourse.fromJson(courseJson());

  VocabProfile profileMissing(List<String> wrong) => VocabProfile.of(
    course: course,
    level: 2,
    results: [
      VocabLevelResult(
        level: 2,
        phase: VocabPhase.pre,
        subSkills: [
          for (final id in vocabSubSkillIds)
            VocabSubSkillScore(
              subSkillId: id,
              correct: wrong.contains(id) ? 0 : 1,
              total: 1,
            ),
        ],
        answers: const {},
      ),
    ],
  );

  ProviderContainer seeded({List<String> missing = const ['collocations']}) {
    final container = ProviderContainer(
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(
          FakeVocabularyRepository(),
        ),
        vocabProgressRepositoryProvider.overrideWithValue(
          FakeVocabProgressRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(vocabPlanProvider.notifier).adopt(profileMissing(missing));
    return container;
  }

  group('the view model', () {
    test('deals the set’s authored questions, shuffled', () async {
      final container = seeded();
      const key = (level: 2, chunkId: 'l2-collocations-1');

      container.read(vocabPracticeViewModelProvider(key));
      await container.read(vocabLevelProvider(2).future);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(vocabPracticeViewModelProvider(key));
      expect(state.status, VocabPracticeStatus.inProgress);
      expect(state.total, 1);
      expect(state.chunkTitle, 'Chunk for collocations');
      expect(state.revealed, isFalse);
    });

    test('choosing reveals, and choosing again cannot change it', () async {
      final container = seeded();
      const key = (level: 2, chunkId: 'l2-collocations-1');
      container.read(vocabPracticeViewModelProvider(key));
      await container.read(vocabLevelProvider(2).future);
      await Future<void>.delayed(Duration.zero);

      final model = container.read(
        vocabPracticeViewModelProvider(key).notifier,
      );
      final item = container.read(vocabPracticeViewModelProvider(key)).current!;
      final wrong = item.options.firstWhere(
        (o) => o.id != item.correctOptionId,
      );

      model.choose(wrong.id);
      model.choose(item.correctOptionId);

      final state = container.read(vocabPracticeViewModelProvider(key));
      expect(state.revealed, isTrue);
      expect(
        state.chosenOptionId,
        wrong.id,
        reason: 'switching after reading the explanation is guessing',
      );
      expect(state.isCorrect, isFalse);
    });

    test('finishing marks the set done whatever the score', () async {
      final container = seeded();
      const key = (level: 2, chunkId: 'l2-collocations-1');
      container.read(vocabPracticeViewModelProvider(key));
      await container.read(vocabLevelProvider(2).future);
      await Future<void>.delayed(Duration.zero);

      final model = container.read(
        vocabPracticeViewModelProvider(key).notifier,
      );
      final item = container.read(vocabPracticeViewModelProvider(key)).current!;
      model.choose(
        item.options.firstWhere((o) => o.id != item.correctOptionId).id,
      );
      model.next();
      // The completion is written without being awaited, so the summary is
      // never held up by it. Let it land before asking whether it did.
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(vocabPracticeViewModelProvider(key)).status,
        VocabPracticeStatus.finished,
      );
      expect(
        container.read(vocabPlanProvider).value!.isDone('l2-collocations-1'),
        isTrue,
        reason: 'a wrong answer read through is still work done',
      );
    });

    test('nothing advances until an answer has been read', () async {
      final container = seeded();
      const key = (level: 2, chunkId: 'l2-collocations-1');
      container.read(vocabPracticeViewModelProvider(key));
      await container.read(vocabLevelProvider(2).future);
      await Future<void>.delayed(Duration.zero);

      container.read(vocabPracticeViewModelProvider(key).notifier).next();

      expect(
        container.read(vocabPracticeViewModelProvider(key)).status,
        VocabPracticeStatus.inProgress,
      );
    });
  });

  group('on screen', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      List<String> missing = const ['collocations'],
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = seeded(missing: missing);
      final router = GoRouter(
        initialLocation: Routes.vocabularyPath,
        routes: [
          GoRoute(
            path: Routes.vocabularyPath,
            builder: (_, _) => const VocabPathScreen(),
            routes: [
              GoRoute(
                path: ':chunkId',
                builder: (_, state) =>
                    VocabWordsScreen(chunkId: state.pathParameters['chunkId']!),
                routes: [
                  GoRoute(
                    path: 'practice',
                    builder: (_, state) => VocabPracticeScreen(
                      chunkId: state.pathParameters['chunkId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    /// Walks from the plan through the word cards into the practice.
    Future<void> openPractice(WidgetTester tester) async {
      await tester.tap(find.text('Area 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise these — 1 question'));
      await tester.pumpAndSettle();
    }

    testWidgets('explains the answer in both languages the moment it is '
        'chosen', (tester) async {
      await pump(tester);
      await openPractice(tester);

      expect(find.text('Question 1 of 1'), findsOneWidget);
      expect(find.text('NOT QUITE'), findsNothing);

      await tester.tap(find.text('Option b'));
      await tester.pumpAndSettle();

      expect(find.text('NOT QUITE'), findsOneWidget);
      expect(find.textContaining('English feedback'), findsOneWidget);
      expect(find.textContaining('বাংলা'), findsOneWidget);
    });

    testWidgets('a right answer is told so', (tester) async {
      await pump(tester);
      await openPractice(tester);

      await tester.tap(find.text('Option a'));
      await tester.pumpAndSettle();

      expect(find.text('THAT’S RIGHT'), findsOneWidget);
    });

    testWidgets('the summary offers the next set when there is one', (
      tester,
    ) async {
      await pump(tester, missing: const ['collocations', 'word_usage']);
      await openPractice(tester);
      await tester.tap(find.text('Option a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 1 right'), findsOneWidget);
      expect(find.text('Next word set'), findsOneWidget);
    });

    testWidgets('the last set sends the learner back to the plan, ticked off', (
      tester,
    ) async {
      await pump(tester);
      await openPractice(tester);
      await tester.tap(find.text('Option a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Back to your plan'), findsOneWidget);
      await tester.tap(find.text('Back to your plan'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 1 done'), findsOneWidget);
    });
  });
}
