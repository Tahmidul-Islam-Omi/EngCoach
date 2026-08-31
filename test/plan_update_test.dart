import 'package:engcoach/data/models/assessment_paper.dart';
import 'package:engcoach/data/models/assessment_result.dart';
import 'package:engcoach/data/models/topic_status.dart';
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

  group('the plan a result leaves behind', () {
    test('the first check sets it to what came back weak', () {
      final update = planUpdate(
        resultWith(
          phase: AssessmentPhase.pre,
          qualified: {'a': true, 'b': false, 'c': false},
        ),
      );

      expect(update['weakSubSkills'], ['b', 'c']);
      expect(update['completedSubSkills'], isEmpty);
    });

    test('the final check replaces it with what is still weak', () {
      // The plan is meant to say what the learner still needs. One built
      // from a measurement three lessons ago no longer does.
      final update = planUpdate(
        resultWith(
          phase: AssessmentPhase.post,
          qualified: {'a': true, 'b': false, 'c': true},
        ),
      );

      expect(update['weakSubSkills'], ['b']);
    });

    test('a new plan always starts with nothing done', () {
      // Leaving old ticks would mark the fresh round finished before it
      // began, and re-offer the final check the moment it ended.
      for (final phase in AssessmentPhase.values) {
        final update = planUpdate(
          resultWith(phase: phase, qualified: {'a': false, 'b': false}),
        );

        expect(update['completedSubSkills'], isEmpty, reason: phase.name);
      }
    });

    test('a clean sheet leaves nothing to teach', () {
      final update = planUpdate(
        resultWith(
          phase: AssessmentPhase.post,
          qualified: {'a': true, 'b': true},
        ),
      );

      expect(update['weakSubSkills'], isEmpty);
    });
  });

  group('how far a result carries the topic', () {
    test('the first check leaves them tested', () {
      expect(
        resultWith(phase: AssessmentPhase.pre, qualified: {'a': true}).reaches,
        TopicStatus.tested,
      );
    });

    test('a final check that still finds gaps leaves them learning', () {
      // It has just handed them another round of lessons — calling that
      // "completed" would contradict the plan on the very next screen.
      expect(
        resultWith(
          phase: AssessmentPhase.post,
          qualified: {'a': true, 'b': false},
        ).reaches,
        TopicStatus.learning,
      );
    });

    test('a clean final check completes the topic', () {
      expect(
        resultWith(
          phase: AssessmentPhase.post,
          qualified: {'a': true, 'b': true},
        ).reaches,
        TopicStatus.completed,
      );
    });

    test('retaking the first check cannot undo a finished topic', () {
      final retake = resultWith(
        phase: AssessmentPhase.pre,
        qualified: {'a': false},
      );

      expect(
        TopicStatus.completed.furthest(retake.reaches),
        TopicStatus.completed,
      );
    });
  });
}
