import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_ladder.dart';
import 'package:engcoach/data/models/vocabulary/vocab_paper.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/view/vocab_path_screen.dart';
import 'package:engcoach/features/vocabulary/view/vocab_words_screen.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_plan_view_model.dart';
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

  /// Pumps the plan and the words screen behind a real router, so tapping a
  /// row navigates the way it does on a device.
  Future<ProviderContainer> pumpPath(
    WidgetTester tester, {
    List<String>? missing,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    if (missing != null) {
      container.read(vocabPlanProvider.notifier).adopt(profileMissing(missing));
    }

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
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('the plan', () {
    testWidgets('with no check taken, points at the check', (tester) async {
      await pumpPath(tester);

      expect(find.text('Take the check first.'), findsOneWidget);
      expect(find.text('Start the check'), findsOneWidget);
    });

    testWidgets('lists only the areas the check flagged', (tester) async {
      await pumpPath(tester, missing: const ['collocations', 'word_usage']);

      expect(find.text('Level 2 — Developing'), findsOneWidget);
      expect(find.text('0 of 2 done'), findsOneWidget);
      expect(find.text('Area 2'), findsOneWidget); // word_usage
      expect(find.text('Area 4'), findsOneWidget); // collocations
      expect(find.text('Area 1'), findsNothing, reason: 'word_meaning cleared');
    });

    testWidgets('names the word set and how many words it holds', (
      tester,
    ) async {
      await pumpPath(tester, missing: const ['collocations']);

      expect(find.textContaining('2 words'), findsOneWidget);
    });

    testWidgets('a clear check has nothing to teach', (tester) async {
      await pumpPath(tester, missing: const []);

      expect(find.text('Nothing to study here.'), findsOneWidget);
    });
  });

  group('the final check', () {
    testWidgets('is offered only once every set is practised', (tester) async {
      await pumpPath(tester, missing: const ['collocations', 'word_usage']);

      expect(find.text('Take the final check'), findsNothing);
    });

    testWidgets('appears when the last set is done', (tester) async {
      final container = await pumpPath(tester, missing: const ['collocations']);
      await container
          .read(vocabPlanProvider.notifier)
          .markChunkComplete('l2-collocations-1');
      await tester.pumpAndSettle();

      expect(find.text('Take the final check'), findsOneWidget);
      expect(find.text('Now see how much changed.'), findsOneWidget);
    });
  });

  group('the words', () {
    testWidgets('opens on the first word of the set', (tester) async {
      await pumpPath(tester, missing: const ['collocations']);
      await tester.tap(find.text('Area 4'));
      await tester.pumpAndSettle();

      expect(find.text('Word 1 of 2'), findsOneWidget);
      expect(find.text('reluctant'), findsOneWidget);
      expect(find.text('adjective'), findsOneWidget);
      expect(find.text('IN A SENTENCE'), findsOneWidget);
      expect(find.text('reluctant + to + verb'), findsOneWidget);
      expect(find.text('unwilling, hesitant'), findsOneWidget);
    });

    testWidgets('a card with only the essentials shows only those', (
      tester,
    ) async {
      await pumpPath(tester, missing: const ['collocations']);
      await tester.tap(find.text('Area 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();

      expect(find.text('Word 2 of 2'), findsOneWidget);
      expect(find.text('busy'), findsOneWidget);
      expect(find.text('IN A SENTENCE'), findsOneWidget);
      expect(
        find.text('HOW IT IS USED'),
        findsNothing,
        reason: 'a simple word should not be padded with empty headings',
      );
      expect(find.text('SAME'), findsNothing);
      expect(find.text('GOES WITH'), findsNothing);
    });

    testWidgets('leaving a set and coming back resumes where it was', (
      tester,
    ) async {
      await pumpPath(tester, missing: const ['collocations']);
      await tester.tap(find.text('Area 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.text('Word 2 of 2'), findsOneWidget);

      // Out to the plan and back in, the way leaving for the Home tab does.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Area 4'));
      await tester.pumpAndSettle();

      expect(
        find.text('Word 2 of 2'),
        findsOneWidget,
        reason:
            'paging through every card again to reach the practice '
            'button is the whole complaint',
      );
      expect(find.text('Practise these — 1 question'), findsOneWidget);
    });

    testWidgets('the last card offers the practice, not a finish', (
      tester,
    ) async {
      final container = await pumpPath(tester, missing: const ['collocations']);
      await tester.tap(find.text('Area 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();

      expect(find.text('Practise these — 1 question'), findsOneWidget);
      expect(find.text('Done for now'), findsOneWidget);

      await tester.tap(find.text('Done for now'));
      await tester.pumpAndSettle();

      expect(
        container.read(vocabPlanProvider).value!.completedChunkIds,
        isEmpty,
        reason: 'reading six cards is not evidence that anything stuck',
      );
      expect(find.text('0 of 1 done'), findsOneWidget);
    });
  });
}
