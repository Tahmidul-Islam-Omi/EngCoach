import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_ladder.dart';
import 'package:engcoach/data/models/vocabulary/vocab_paper.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/vocabulary_fixture.dart';

void main() {
  final course = VocabCourse.fromJson(courseJson());

  VocabProfile profileMissing(List<String> wrong, {int level = 2}) =>
      VocabProfile.of(
        course: course,
        level: level,
        results: [
          VocabLevelResult(
            level: level,
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

  test('a plan is read off the profile, in authored order', () {
    final plan = VocabPlan.fromProfile(
      profileMissing(const ['word_formation', 'word_usage']),
    );

    expect(plan.level, 2);
    expect(plan.focusSubSkillIds, ['word_usage', 'word_formation']);
    expect(plan.completedChunkIds, isEmpty);
  });

  test('a clear profile leaves nothing to teach', () {
    expect(VocabPlan.fromProfile(profileMissing(const [])).isEmpty, isTrue);
  });

  test('finishing a chunk marks it, and marking it twice changes nothing', () {
    final plan = VocabPlan.fromProfile(profileMissing(const ['collocations']));

    final once = plan.withChunkDone('l2-collocations-1');
    final twice = once.withChunkDone('l2-collocations-1');

    expect(once.isDone('l2-collocations-1'), isTrue);
    expect(twice.completedChunkIds, hasLength(1));
    expect(
      plan.isDone('l2-collocations-1'),
      isFalse,
      reason: 'the original plan is immutable',
    );
  });
}
