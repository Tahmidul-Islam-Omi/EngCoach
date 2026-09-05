import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/view/vocab_path_screen.dart';
import 'package:engcoach/features/vocabulary/view/vocab_practice_screen.dart';
import 'package:engcoach/features/vocabulary/view/vocab_words_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

/// Opens a vocabulary screen the way a relaunch does: with a plan already in
/// Firestore and nothing yet read from it.
///
/// The bug this guards against is a screen treating "still loading" as "no
/// plan", and telling a learner who has one that their words do not exist.
void main() {
  final stored = const VocabPlan(
    level: 2,
    focusSubSkillIds: ['collocations'],
    before: [
      VocabSubSkillScore(subSkillId: 'collocations', correct: 0, total: 1),
    ],
  );

  Future<void> pumpAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: Routes.vocabularyPath,
          builder: (_, _) => const VocabPathScreen(),
          routes: [
            GoRoute(
              path: ':chunkId',
              builder: (_, s) =>
                  VocabWordsScreen(chunkId: s.pathParameters['chunkId']!),
              routes: [
                GoRoute(
                  path: 'practice',
                  builder: (_, s) => VocabPracticeScreen(
                    chunkId: s.pathParameters['chunkId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyRepositoryProvider.overrideWithValue(
            FakeVocabularyRepository(),
          ),
          vocabProgressRepositoryProvider.overrideWithValue(
            FakeVocabProgressRepository(
              stored,
              const Duration(milliseconds: 50),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
  }

  testWidgets('the word cards never say the words are missing', (tester) async {
    await pumpAt(tester, '/vocabulary/learn/l2-collocations-1');

    // The first frame, before Firestore has answered.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('These words are not available yet.'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 2'), findsOneWidget);
  });

  testWidgets('practice never says to take the check first', (tester) async {
    await pumpAt(tester, '/vocabulary/learn/l2-collocations-1/practice');

    await tester.pump();
    // Positive first: prove the screen really is in its loading state, so the
    // absence below is evidence rather than an empty frame.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.textContaining('Take the check first'),
      findsNothing,
      reason: 'the learner has a plan; it simply has not arrived yet',
    );

    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);
  });

  testWidgets('the plan never says to take the check first', (tester) async {
    await pumpAt(tester, Routes.vocabularyPath);

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Take the check first.'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Level 2 — Developing'), findsOneWidget);
  });
}
