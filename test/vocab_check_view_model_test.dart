import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/vocabulary/model/vocab_check_state.dart';
import 'package:engcoach/features/vocabulary/viewmodel/vocab_check_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  /// Lets the imperative content loads inside the view model finish. The fake
  /// repository completes on a microtask, so one turn of the loop is enough
  /// per await it has to get through.
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ({ProviderContainer container, VocabCheckViewModel model}) start({
    int? failLevel,
    int bankSize = 3,
  }) {
    final container = ProviderContainer(
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(
          FakeVocabularyRepository(failLevel: failLevel, bankSize: bankSize),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(vocabCheckViewModelProvider);
    return (
      container: container,
      model: container.read(vocabCheckViewModelProvider.notifier),
    );
  }

  /// Answers every question on the paper in front of the learner, getting the
  /// ones for [wrong] subskills deliberately wrong.
  Future<void> answerPaper(
    ProviderContainer c,
    VocabCheckViewModel model, {
    Set<String> wrong = const {},
  }) async {
    // Stops when this paper is done rather than when answering stops being
    // possible: climbing deals a new paper, and the loop would run the whole
    // ladder in one call.
    final paper = c.read(vocabCheckViewModelProvider).paper;

    while (true) {
      final state = c.read(vocabCheckViewModelProvider);
      if (state.status != VocabCheckStatus.inProgress ||
          !identical(state.paper, paper)) {
        return;
      }

      final q = state.current!;
      final correct = q.correctOptionId;
      final other = q.options.firstWhere((o) => o.id != correct).id;
      model.select(wrong.contains(q.subSkillId) ? other : correct);
      model.next();
      await settle();
    }
  }

  group('starting the check', () {
    test('deals level 1, one question per subskill', () async {
      final (:container, :model) = start();
      await settle();

      final state = container.read(vocabCheckViewModelProvider);
      expect(state.status, VocabCheckStatus.inProgress);
      expect(state.level, 1);
      expect(state.total, 6);
      expect(state.position, 1);
      expect(state.isProbe, isFalse);
    });

    test('content that will not load is reported, not swallowed', () async {
      final (:container, :model) = start(failLevel: 1);
      await settle();

      final state = container.read(vocabCheckViewModelProvider);
      expect(state.status, VocabCheckStatus.failed);
      expect(state.error, contains('Level 1'));
    });
  });

  group('answering', () {
    test('nothing advances until something is chosen', () async {
      final (:container, :model) = start();
      await settle();

      expect(container.read(vocabCheckViewModelProvider).canAdvance, isFalse);
      model.next();
      expect(container.read(vocabCheckViewModelProvider).position, 1);

      model.select(
        container.read(vocabCheckViewModelProvider).current!.options.first.id,
      );
      model.next();
      expect(container.read(vocabCheckViewModelProvider).position, 2);
    });

    test('going back keeps the answer so it can be changed', () async {
      final (:container, :model) = start();
      await settle();

      final first = container.read(vocabCheckViewModelProvider).current!;
      model.select(first.options.first.id);
      model.next();
      model.previous();

      final state = container.read(vocabCheckViewModelProvider);
      expect(state.position, 1);
      expect(state.selectedOptionId, first.options.first.id);
    });
  });

  group('the ladder', () {
    test('a clean sheet climbs to the next level', () async {
      final (:container, :model) = start();
      await settle();
      await answerPaper(container, model);

      final state = container.read(vocabCheckViewModelProvider);
      expect(state.level, 2);
      expect(state.status, VocabCheckStatus.inProgress);
      expect(state.history, hasLength(1));
      expect(state.answers, isEmpty, reason: 'a new level is a fresh paper');
    });

    test('a borderline level stops and explains before asking more', () async {
      final (:container, :model) = start();
      await settle();
      await answerPaper(
        container,
        model,
        wrong: const {'collocations', 'word_formation'},
      );

      final state = container.read(vocabCheckViewModelProvider);
      expect(state.status, VocabCheckStatus.borderline);
      expect(
        state.level,
        1,
        reason: 'the ladder has not decided yet, so it has not moved',
      );
    });

    test(
      'the probe asks only about what was missed, and nothing twice',
      () async {
        final (:container, :model) = start();
        await settle();
        final firstPaper = container.read(vocabCheckViewModelProvider).paper!;
        await answerPaper(
          container,
          model,
          wrong: const {'collocations', 'word_formation'},
        );

        model.continueToProbe();
        final state = container.read(vocabCheckViewModelProvider);

        expect(state.isProbe, isTrue);
        expect(state.paper!.subSkillIds, ['collocations', 'word_formation']);
        expect(
          state.paper!.questionIds.intersection(firstPaper.questionIds),
          isEmpty,
          reason: 'a second look at the same item is not new evidence',
        );
      },
    );

    test('a passed probe climbs; a failed one settles', () async {
      for (final (wrongOnProbe, expectedLevel, expectedStatus) in [
        (const <String>{}, 2, VocabCheckStatus.inProgress),
        (const {'collocations'}, 1, VocabCheckStatus.finished),
      ]) {
        final (:container, :model) = start();
        await settle();
        await answerPaper(
          container,
          model,
          wrong: const {'collocations', 'word_formation'},
        );
        model.continueToProbe();
        await answerPaper(container, model, wrong: wrongOnProbe);

        final state = container.read(vocabCheckViewModelProvider);
        expect(state.level, expectedLevel);
        expect(state.status, expectedStatus);
      }
    });

    test('a poor level settles at once, with no probe offered', () async {
      final (:container, :model) = start();
      await settle();
      await answerPaper(
        container,
        model,
        wrong: const {'collocations', 'word_formation', 'word_usage'},
      );

      final state = container.read(vocabCheckViewModelProvider);
      expect(
        state.status,
        VocabCheckStatus.finished,
        reason: 'a struggling learner should not be asked to keep going',
      );
      expect(state.level, 1);
    });

    test(
      'clearing every level settles at the top rather than climbing off it',
      () async {
        final (:container, :model) = start();
        await settle();
        for (var i = 0; i < 4; i++) {
          await answerPaper(container, model);
        }

        final state = container.read(vocabCheckViewModelProvider);
        expect(state.status, VocabCheckStatus.finished);
        expect(state.level, 4);
        expect(state.history, hasLength(4));
      },
    );
  });

  group('the profile', () {
    test(
      'focus comes from the level settled at, aggregates from the whole run',
      () async {
        final (:container, :model) = start();
        await settle();
        // Level 1 clean, level 2 missed three — settles at 2.
        await answerPaper(container, model);
        await answerPaper(
          container,
          model,
          wrong: const {'collocations', 'word_formation', 'word_usage'},
        );

        final profile = container.read(vocabCheckViewModelProvider).profile!;

        expect(profile.level, 2);
        expect(
          profile.focusSubSkillIds,
          ['word_usage', 'collocations', 'word_formation'],
          reason: 'authored order, not the order they were missed in',
        );
        expect(
          profile.scoreFor('word_meaning')!.total,
          2,
          reason: 'both levels count towards the evidence',
        );
        expect(profile.scoreFor('collocations')!.correct, 1);
      },
    );

    test('a learner who slips nowhere has nothing to teach', () async {
      final (:container, :model) = start();
      await settle();
      for (var i = 0; i < 4; i++) {
        await answerPaper(container, model);
      }

      expect(
        container.read(vocabCheckViewModelProvider).profile!.allClear,
        isTrue,
      );
    });
  });

  test('restarting deals a fresh run from level 1', () async {
    final (:container, :model) = start();
    await settle();
    await answerPaper(container, model);
    expect(container.read(vocabCheckViewModelProvider).level, 2);

    model.restart();
    await settle();

    final state = container.read(vocabCheckViewModelProvider);
    expect(state.level, 1);
    expect(state.history, isEmpty);
    expect(state.status, VocabCheckStatus.inProgress);
  });
}
