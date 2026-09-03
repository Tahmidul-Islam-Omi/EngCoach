import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/view/vocab_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/vocabulary_fixture.dart';

void main() {
  Future<void> pumpCheck(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyRepositoryProvider.overrideWithValue(
            FakeVocabularyRepository(),
          ),
        ],
        // The real theme, so button sizing and text scale match the device
        // and an overflow here would be an overflow there.
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VocabCheckScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Answers the paper on screen, missing the questions for [wrong].
  Future<void> answerPaper(
    WidgetTester tester, {
    Set<String> wrong = const {},
    int length = 6,
  }) async {
    for (var i = 0; i < length; i++) {
      final options = tester.widgetList<InkWell>(find.byType(InkWell)).length;
      expect(options, greaterThan(0));
      // Option A is the fixture's correct answer; B is always wrong.
      final subSkill = vocabSubSkillIds.length > i ? vocabSubSkillIds[i] : '';
      await tester.tap(
        find.text(wrong.contains(subSkill) ? 'Option b' : 'Option a'),
      );
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
  }

  group('the question screen', () {
    testWidgets('opens on the first question of level 1', (tester) async {
      await pumpCheck(tester);

      expect(find.text('Vocabulary check'), findsOneWidget);
      expect(find.text('LEVEL 1'), findsOneWidget);
      expect(find.text('Question 1 of 6'), findsOneWidget);

      final next = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(next.onPressed, isNull, reason: 'nothing chosen yet');
    });

    testWidgets('never names the subskill it is measuring', (tester) async {
      await pumpCheck(tester);

      for (var i = 1; i <= vocabSubSkillIds.length; i++) {
        expect(
          find.textContaining('Area $i'),
          findsNothing,
          reason: 'naming the area a question measures steers the answer',
        );
      }
    });

    testWidgets('choosing an option enables moving on', (tester) async {
      await pumpCheck(tester);

      await tester.tap(find.text('Option a'));
      await tester.pump();

      final next = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(next.onPressed, isNotNull);
    });
  });

  group('the ladder on screen', () {
    testWidgets('a clean level carries straight on to the next', (
      tester,
    ) async {
      await pumpCheck(tester);
      await answerPaper(tester);

      expect(find.text('LEVEL 2'), findsOneWidget);
      expect(find.text('Question 1 of 6'), findsOneWidget);
    });

    testWidgets('a borderline level explains itself without naming areas', (
      tester,
    ) async {
      await pumpCheck(tester);
      await answerPaper(
        tester,
        wrong: const {'collocations', 'word_formation'},
      );

      expect(find.text('You were close.'), findsOneWidget);
      for (var i = 1; i <= vocabSubSkillIds.length; i++) {
        expect(find.textContaining('Area $i'), findsNothing);
      }

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Question 1 of 2'), findsOneWidget);
    });
  });

  group('the result', () {
    testWidgets('names the level and marks the areas to work on', (
      tester,
    ) async {
      await pumpCheck(tester);
      await answerPaper(
        tester,
        wrong: const {'collocations', 'word_formation', 'word_usage'},
      );

      expect(find.text('YOUR LEVEL'), findsOneWidget);
      expect(find.text('Level 1 — Developing'), findsOneWidget);
      expect(find.text("Here's what to work on."), findsOneWidget);
      // The breakdown sits below the fold on a 360dp screen, and a ListView
      // only inflates what is near the viewport.
      await tester.scrollUntilVisible(
        find.text('Area 2'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('FOCUS'), findsWidgets);
    });

    testWidgets('a learner who clears everything is told so', (tester) async {
      await pumpCheck(tester);
      for (var i = 0; i < 4; i++) {
        await answerPaper(tester);
      }

      expect(find.text('Nothing here needs work.'), findsOneWidget);
      expect(find.text('FOCUS'), findsNothing);
      expect(find.text('Back to vocabulary'), findsOneWidget);
    });
  });
}
