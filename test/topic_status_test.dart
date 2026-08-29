import 'package:engcoach/data/models/assessment_paper.dart';
import 'package:engcoach/data/models/topic_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('furthest never walks a learner backwards', () {
    // Finishing a lesson must not undo a completed or mastered topic — a
    // second device catching up on old work would otherwise demote them.
    expect(
      TopicStatus.completed.furthest(TopicStatus.learning),
      TopicStatus.completed,
    );
    expect(
      TopicStatus.mastered.furthest(TopicStatus.learning),
      TopicStatus.mastered,
    );
  });

  test('furthest moves forward when it should', () {
    expect(
      TopicStatus.tested.furthest(TopicStatus.learning),
      TopicStatus.learning,
    );
    expect(
      TopicStatus.notStarted.furthest(TopicStatus.learning),
      TopicStatus.learning,
    );
  });

  test('an assessment establishes a floor, not a value', () {
    expect(AssessmentPhase.pre.reaches, TopicStatus.tested);
    expect(AssessmentPhase.post.reaches, TopicStatus.completed);
  });

  test('retaking the first check cannot undo a finished topic', () {
    // The bug this replaced: saveAssessment wrote `tested` outright, so a
    // learner who retook the opening check lost a completed topic.
    expect(
      TopicStatus.completed.furthest(AssessmentPhase.pre.reaches),
      TopicStatus.completed,
    );
    expect(
      TopicStatus.mastered.furthest(AssessmentPhase.pre.reaches),
      TopicStatus.mastered,
    );
    // But a first check on an untouched topic still moves it along.
    expect(
      TopicStatus.notStarted.furthest(AssessmentPhase.pre.reaches),
      TopicStatus.tested,
    );
    // And the final check still completes a topic being learned.
    expect(
      TopicStatus.learning.furthest(AssessmentPhase.post.reaches),
      TopicStatus.completed,
    );
  });

  test('the order is the one SPEC 7 describes', () {
    expect(TopicStatus.values, [
      TopicStatus.notStarted,
      TopicStatus.tested,
      TopicStatus.learning,
      TopicStatus.completed,
      TopicStatus.mastered,
    ]);
  });
}
