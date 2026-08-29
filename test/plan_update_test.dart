import 'package:engcoach/data/models/assessment_paper.dart';
import 'package:engcoach/data/models/assessment_result.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A scored result with the given sub-skills passing or failing.
  AssessmentResult resultWith({
    required AssessmentPhase phase,
    required Map<String, bool> qualified,
  }) {
    return AssessmentResult(
      topicId: 'present_simple',
      phase: phase,
      answers: const {},
      subSkills: [
        for (final e in qualified.entries)
          SubSkillScore(
            subSkillId: e.key,
            title: e.key,
            correct: e.value ? 2 : 1,
            total: 2,
            qualified: e.value,
          ),
      ],
    );
  }

  group('the first check', () {
    test('sets the plan to what it found weak', () {
      final update = planUpdate(
        result: resultWith(
          phase: AssessmentPhase.pre,
          qualified: {'a': true, 'b': false, 'c': false},
        ),
        storedDone: const [],
      );

      expect(update['weakSubSkills'], ['b', 'c']);
      expect(update['completedSubSkills'], isEmpty);
    });

    test('keeps work on sub-skills still in the new plan', () {
      final update = planUpdate(
        result: resultWith(
          phase: AssessmentPhase.pre,
          qualified: {'a': false, 'b': false},
        ),
        storedDone: const ['a'],
      );

      expect(update['weakSubSkills'], ['a', 'b']);
      expect(update['completedSubSkills'], ['a']);
    });

    test('drops work on sub-skills the learner has since passed', () {
      // Otherwise "2 of 1 done" is reachable, and the final check gets
      // offered on a plan that was never finished.
      final update = planUpdate(
        result: resultWith(
          phase: AssessmentPhase.pre,
          qualified: {'a': true, 'b': false},
        ),
        storedDone: const ['a', 'b'],
      );

      expect(update['weakSubSkills'], ['b']);
      expect(update['completedSubSkills'], ['b']);
    });

    test('a clean sheet leaves nothing to teach', () {
      final update = planUpdate(
        result: resultWith(
          phase: AssessmentPhase.pre,
          qualified: {'a': true, 'b': true},
        ),
        storedDone: const ['a'],
      );

      expect(update['weakSubSkills'], isEmpty);
      expect(update['completedSubSkills'], isEmpty);
    });
  });

  group('the final check', () {
    test('does not touch the plan at all', () {
      // It measures whether the lessons worked. Rewriting the plan from it
      // wiped the ticks beside the lessons that had just been done.
      final update = planUpdate(
        result: resultWith(
          phase: AssessmentPhase.post,
          qualified: {'a': false, 'b': true},
        ),
        storedDone: const ['a', 'b'],
      );

      expect(update, isEmpty);
    });

    test('leaves completions alone even when it goes badly', () {
      final update = planUpdate(
        result: resultWith(
          phase: AssessmentPhase.post,
          qualified: {'a': false, 'b': false},
        ),
        storedDone: const ['a', 'b'],
      );

      expect(update.containsKey('completedSubSkills'), isFalse);
      expect(update.containsKey('weakSubSkills'), isFalse);
    });
  });
}
