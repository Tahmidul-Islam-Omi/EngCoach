import 'package:engcoach/data/models/lesson.dart';
import 'package:engcoach/data/models/lesson_block.dart';
import 'package:engcoach/data/models/question.dart';
import 'package:engcoach/data/models/topic.dart';

/// Builds a topic with predictable ids, so a test can assert on exactly
/// which questions were drawn without reading authored content.
///
/// Question ids read `s1-pre-2`; option ids read `s1-pre-2-c`, with the
/// correct one always at [correctAt] in the authored order — which is what
/// makes "the shuffle kept exactly one correct option" checkable.
Topic buildTopic({
  String id = 'test_topic',
  String title = 'Test topic',
  int subSkills = 3,
  int bankSize = 6,
  int questionsPerSubSkill = 3,
  int qualifyingScore = 3,
  int optionCount = 4,
  int correctAt = 0,
}) {
  final skills = [
    for (var s = 1; s <= subSkills; s++)
      SubSkill(
        id: 's$s',
        title: 'Sub-skill $s',
        preAssessmentBank: [
          for (var q = 1; q <= bankSize; q++)
            _question('s$s-pre-$q', optionCount, correctAt),
        ],
        postAssessmentBank: [
          for (var q = 1; q <= bankSize; q++)
            _question('s$s-post-$q', optionCount, correctAt),
        ],
      ),
  ];

  return Topic(
    id: id,
    section: 'grammar',
    order: 1,
    title: title,
    summary: 'For tests.',
    whyThisTopic: 'Because tests.',
    assessmentConfig: AssessmentConfig(
      questionsPerSubSkill: questionsPerSubSkill,
      qualifyingScore: qualifyingScore,
    ),
    subSkills: skills,
    lessons: [
      for (final s in skills)
        Lesson(
          id: '${s.id}-lesson',
          subSkillId: s.id,
          // Distinct from the sub-skill's own title, as real content is:
          // "Base verb form" the sub-skill, "I, you, we, they — the base
          // verb" the lesson.
          title: 'Lesson for ${s.title}',
          blocks: const [TextBlock(text: 'Body.')],
          practice: const [],
        ),
    ],
  );
}

Question _question(String id, int optionCount, int correctAt) {
  return Question(
    id: id,
    rule: 'rule',
    instruction: 'Choose one.',
    prompt: 'Prompt for $id',
    options: [
      for (var i = 0; i < optionCount; i++)
        QuestionOption(
          id: '$id-${String.fromCharCode(97 + i)}',
          text: 'Option ${String.fromCharCode(97 + i)}',
          correct: i == correctAt,
        ),
    ],
  );
}
