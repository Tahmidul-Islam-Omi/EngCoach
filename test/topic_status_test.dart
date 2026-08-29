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
