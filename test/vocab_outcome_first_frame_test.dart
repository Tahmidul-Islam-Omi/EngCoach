import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_ladder.dart';
import 'package:engcoach/data/models/vocabulary/vocab_paper.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/view/vocab_final_check_screen.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_final_check_view_model.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_plan_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/vocabulary_fixture.dart';

/// Drives the final check through its own screen, end to end, and checks the
/// outcome reads correctly for a perfect score.
///
/// Written while chasing a suspected one-frame flicker: the plan is rewritten
/// by a write that is not awaited, so in principle the outcome could render
/// against the stale plan. It cannot in practice — microtasks drain before a
/// frame paints — and this test passes either way. It earns its place as the
/// only end-to-end cover of the outcome screen, not as a regression guard.
void main() {
  testWidgets('a full score reads as a cleared level', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final course = VocabCourse.fromJson(courseJson());
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

    await container
        .read(vocabPlanProvider.notifier)
        .adopt(
          VocabProfile.of(
            course: course,
            level: 2,
            results: [
              VocabLevelResult(
                level: 2,
                phase: VocabPhase.pre,
                answers: const {},
                subSkills: [
                  for (final id in vocabSubSkillIds)
                    VocabSubSkillScore(
                      subSkillId: id,
                      correct: id == 'collocations' ? 0 : 1,
                      total: 1,
                    ),
                ],
              ),
            ],
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: Routes.vocabularyFinalCheck,
            routes: [
              GoRoute(
                path: Routes.vocabularyFinalCheck,
                builder: (_, _) => const VocabFinalCheckScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Answer everything correctly.
    while (container.read(vocabFinalCheckProvider).status ==
        VocabFinalStatus.inProgress) {
      // The fixture's right answer always reads "Option a", wherever the
      // shuffle puts it.
      await tester.tap(find.text('Option a'));
      await tester.pump();
      await tester.tap(
        find.text(
          container.read(vocabFinalCheckProvider).isLast ? 'Finish' : 'Next',
        ),
      );
      await tester.pump();
    }

    // One frame only — the stored plan has not been rewritten yet.
    await tester.pump();

    expect(find.text('You have cleared this level.'), findsOneWidget);
    expect(find.text('Nothing moved yet.'), findsNothing);
    expect(find.text('Continue to Level 3'), findsOneWidget);
  });
}
