import 'package:flutter_test/flutter_test.dart';

import 'support/topic_fixture.dart';

void main() {
  final topic = buildTopic(subSkills: 4);

  group('subSkillsNamed', () {
    test('keeps authored order, whatever order it is asked in', () {
      // Teaching order is the content's. Stored progress can hold the ids in
      // any order, and must not reorder the plan.
      expect(
        topic.subSkillsNamed(['s3', 's1']).map((s) => s.id),
        ['s1', 's3'],
      );
    });

    test('drops ids the content no longer has', () {
      // Stored progress outlives content edits, so an id can name a
      // sub-skill that was renamed or removed.
      expect(
        topic.subSkillsNamed(['s2', 'deleted_last_year']).map((s) => s.id),
        ['s2'],
      );
    });

    test('ignores duplicates', () {
      expect(topic.subSkillsNamed(['s1', 's1']).map((s) => s.id), ['s1']);
    });

    test('an empty list means nothing to teach', () {
      expect(topic.subSkillsNamed(const []), isEmpty);
    });

    test('every id returns every sub-skill, in order', () {
      expect(
        topic.subSkillsNamed(['s4', 's3', 's2', 's1']).map((s) => s.id),
        ['s1', 's2', 's3', 's4'],
      );
    });
  });
}
