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

  String get label => switch (this) {
        TopicStatus.notStarted => 'NOT STARTED',
        TopicStatus.tested => 'TESTED',
        TopicStatus.learning => 'LEARNING',
        TopicStatus.completed => 'COMPLETED',
        TopicStatus.mastered => 'MASTERED',
      };
}
