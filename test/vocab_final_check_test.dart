import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_ladder.dart';
import 'package:engcoach/data/models/vocabulary/vocab_paper.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_final_check_view_model.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_plan_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<ProviderContainer> seeded({
    List<String> missing = const ['collocations'],
    List<String> alreadyDone = const ['l2-collocations-1'],
  }) async {
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
        .adopt(profileMissing(missing));
    for (final id in alreadyDone) {
      await container.read(vocabPlanProvider.notifier).markChunkComplete(id);
    }
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('the paper', () {
    test('covers every area and leans on the ones that were taught', () async {
      final container = await seeded();
      container.read(vocabFinalCheckProvider);
      await settle();

      final state = container.read(vocabFinalCheckProvider);
      expect(state.status, VocabFinalStatus.inProgress);
      // One base question each, plus two more on the single focus area.
      expect(state.total, vocabSubSkillIds.length + 2);
      expect(state.paper!.questionsFor('collocations'), hasLength(3));
      expect(state.paper!.questionsFor('word_meaning'), hasLength(1));
    });

    test('draws from the post bank, never the one the check used', () async {
      final container = await seeded();
      container.read(vocabFinalCheckProvider);
      await settle();

      final paper = container.read(vocabFinalCheckProvider).paper!;
      expect(paper.phase, VocabPhase.post);
      expect(paper.questions.every((q) => q.id.contains('-post-')), isTrue);
    });

    test('with no plan there is nothing to measure against', () async {
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
      await container.read(vocabPlanProvider.future);

      container.read(vocabFinalCheckProvider);
      await settle();

      expect(
        container.read(vocabFinalCheckProvider).status,
        VocabFinalStatus.failed,
      );
    });
  });

  group('scoring', () {
    /// Answers the whole paper, missing the questions for [wrong].
    Future<void> answerAll(
      ProviderContainer c, {
      Set<String> wrong = const {},
    }) async {
      final model = c.read(vocabFinalCheckProvider.notifier);
      while (c.read(vocabFinalCheckProvider).status ==
          VocabFinalStatus.inProgress) {
        final q = c.read(vocabFinalCheckProvider).current!;
        final correct = q.correctOptionId;
        final other = q.options.firstWhere((o) => o.id != correct).id;
        model.select(wrong.contains(q.subSkillId) ? other : correct);
        model.next();
      }
      await settle();
    }

    test('the outcome survives the plan write it triggers', () async {
      final container = await seeded();
      container.read(vocabFinalCheckProvider);
      await settle();
      await answerAll(container);
      // The write rewrites the plan. If this view model watched the plan, that
      // write would rebuild it — dealing a fresh paper over the outcome and
      // putting the learner back on question one of a check they finished.
      await settle();

      final state = container.read(vocabFinalCheckProvider);
      expect(state.status, VocabFinalStatus.finished);
      expect(state.result, isNotNull);
    });

    test('a clean sheet leaves nothing to teach', () async {
      final container = await seeded();
      container.read(vocabFinalCheckProvider);
      await settle();
      await answerAll(container);

      final plan = container.read(vocabPlanProvider).value!;
      expect(container.read(vocabFinalCheckProvider).stillWeak, isEmpty);
      expect(plan.isEmpty, isTrue);
      expect(plan.after, isNotNull);
    });

    test(
      'what it still finds replaces the old plan, completions and all',
      () async {
        final container = await seeded();
        expect(
          container.read(vocabPlanProvider).value!.completedChunkIds,
          hasLength(1),
        );

        container.read(vocabFinalCheckProvider);
        await settle();
        await answerAll(container, wrong: const {'phrasal_verbs'});

        final plan = container.read(vocabPlanProvider).value!;
        expect(
          plan.focusSubSkillIds,
          ['phrasal_verbs'],
          reason: 'the areas it still flags replace the ones the check named',
        );
        expect(
          plan.completedChunkIds,
          isEmpty,
          reason:
              'a tick earned against the previous round would mark the new '
              'plan finished before it was started',
        );
      },
    );

    test('the starting point is never overwritten', () async {
      final container = await seeded();
      final before = container.read(vocabPlanProvider).value!.before;

      container.read(vocabFinalCheckProvider);
      await settle();
      await answerAll(container);

      expect(
        container.read(vocabPlanProvider).value!.before.map((s) => s.percent),
        before.map((s) => s.percent),
      );
    });
  });

  group('the stored document', () {
    test('survives a round trip', () {
      final plan = VocabPlan.fromProfile(profileMissing(const ['collocations']))
          .withChunkDone('l2-collocations-1')
          .withFinalCheck(
            after: const [
              VocabSubSkillScore(
                subSkillId: 'collocations',
                correct: 2,
                total: 3,
              ),
            ],
            stillWeak: const ['collocations'],
          );

      final back = planFrom(planToMap(plan).cast<String, dynamic>())!;

      expect(back.level, plan.level);
      expect(back.focusSubSkillIds, plan.focusSubSkillIds);
      expect(back.completedChunkIds, plan.completedChunkIds);
      expect(back.before.length, plan.before.length);
      expect(back.afterFor('collocations')!.percent, 67);
    });

    test('a half-written document is not read as a plan', () {
      expect(planFrom(null), isNull);
      expect(
        planFrom(<String, dynamic>{'focusSubSkills': <String>[]}),
        isNull,
        reason: 'a document with no level would put the learner on Level 0',
      );
    });

    test('a plan that has never been final-checked stores no after', () {
      final map = planToMap(
        VocabPlan.fromProfile(profileMissing(const ['collocations'])),
      );

      expect(map.containsKey('after'), isFalse);
      expect(planFrom(map.cast<String, dynamic>())!.after, isNull);
    });
  });
}
