import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_ladder.dart';
import 'package:engcoach/data/models/vocabulary/vocab_paper.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/view/vocabulary_overview_screen.dart';
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

  Future<void> pumpOverview(
    WidgetTester tester, {
    List<String>? missing,
  }) async {
    tester.view.physicalSize = const Size(360, 900);
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
      await container
          .read(vocabPlanProvider.notifier)
          .adopt(profileMissing(missing));
    }

    final router = GoRouter(
      initialLocation: Routes.vocabulary,
      routes: [
        GoRoute(
          path: Routes.vocabulary,
          builder: (_, _) => const VocabularyOverviewScreen(),
        ),
        GoRoute(
          path: Routes.vocabularyPath,
          builder: (_, _) => const Scaffold(body: Text('the plan')),
        ),
        GoRoute(
          path: Routes.vocabularyCheck,
          builder: (_, _) => const Scaffold(body: Text('the check')),
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
  }

  testWidgets('with no plan, the only way on is the check', (tester) async {
    await pumpOverview(tester);

    expect(find.text('Start the check'), findsOneWidget);
    expect(find.text('Continue your plan'), findsNothing);
  });

  testWidgets('a plan in progress can be returned to', (tester) async {
    await pumpOverview(tester, missing: const ['collocations', 'word_usage']);

    expect(find.text('YOUR PLAN'), findsOneWidget);
    expect(find.text('Level 2 — 0 of 2 word sets done.'), findsOneWidget);

    await tester.tap(find.text('Continue your plan'));
    await tester.pumpAndSettle();
    expect(find.text('the plan'), findsOneWidget);
  });

  testWidgets('a cleared level is offered the next one, not an empty plan', (
    tester,
  ) async {
    // Clearing every area leaves a plan with nothing on it. Treating that the
    // same as "has a plan" offered "continue your plan" and walked the
    // learner into a screen with nothing on it and no way forward.
    await pumpOverview(tester, missing: const []);

    expect(find.text('Check your level again'), findsOneWidget);
    expect(find.text('Continue your plan'), findsNothing);
    expect(
      find.text('Level 2 — cleared. The check can place you higher now.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Check your level again'));
    await tester.pumpAndSettle();

    expect(
      find.text('the check'),
      findsOneWidget,
      reason: 'nothing to lose, so no confirmation to sit through',
    );
  });

  testWidgets('retaking the check asks before it throws the plan away', (
    tester,
  ) async {
    await pumpOverview(tester, missing: const ['collocations']);

    await tester.tap(find.text('Take the check again'));
    await tester.pumpAndSettle();

    expect(find.text('Take the check again?'), findsOneWidget);
    await tester.tap(find.text('Keep my plan'));
    await tester.pumpAndSettle();

    expect(find.text('the check'), findsNothing);

    await tester.tap(find.text('Take the check again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start again'));
    await tester.pumpAndSettle();

    expect(find.text('the check'), findsOneWidget);
  });
}
