/// A topic's place in the learning cycle (SPEC §7).
///
/// The order matters: this is a one-way progression, and [mastered] is only
/// reachable through a spaced review days later — never from the
/// post-assessment alone.
enum TopicStatus {
  notStarted,
  tested,
  learning,
  completed,
  mastered;

  /// The further along of the two.
  ///
  /// Progress is one-way (SPEC §7), so anything that sets a status has to be
  /// able to say "at least this far" without ever walking a learner back —
  /// finishing a lesson must not undo a completed topic.
  TopicStatus furthest(TopicStatus other) =>
      index >= other.index ? this : other;

  String get label => switch (this) {
    TopicStatus.notStarted => 'NOT STARTED',
    TopicStatus.tested => 'TESTED',
    TopicStatus.learning => 'LEARNING',
    TopicStatus.completed => 'COMPLETED',
    TopicStatus.mastered => 'MASTERED',
  };
}
