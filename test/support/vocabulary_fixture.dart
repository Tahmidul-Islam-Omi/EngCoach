/// The six subskills, in the order `course.json` authors them.
const vocabSubSkillIds = [
  'word_meaning',
  'word_usage',
  'synonyms_antonyms',
  'collocations',
  'phrasal_verbs',
  'word_formation',
];

/// The course as it would be authored. Mirrors `content/vocabulary/course.json`
/// but stays under the test's control, so tuning a shipped threshold cannot
/// quietly rewrite what these tests claim to prove.
Map<String, dynamic> courseJson({
  int advanceAt = 5,
  int probeAt = 4,
  int probeSize = 2,
  int probeAdvanceAt = 2,
  int topLevel = 4,
}) => {
  'subSkills': [
    for (final (i, id) in vocabSubSkillIds.indexed)
      {'id': id, 'title': 'Area ${i + 1}'},
  ],
  'ladder': {
    'questionsPerSubSkill': 1,
    'advanceAt': advanceAt,
    'probeAt': probeAt,
    'probeSize': probeSize,
    'probeAdvanceAt': probeAdvanceAt,
    'topLevel': topLevel,
  },
  'finalCheck': {'basePerSubSkill': 1, 'extraPerFocus': 2},
};

/// A level as it would be authored, built as JSON rather than as objects.
///
/// The point of these tests is the schema — that what a writer types parses
/// into the model — so going through `fromJson` is the whole exercise.
/// Constructing the classes directly would test nothing but the constructors.
Map<String, dynamic> levelJson({
  int level = 2,
  List<String> subSkills = vocabSubSkillIds,
  int bankSize = 3,
}) => {
  'level': level,
  'title': 'Developing',
  'summary': 'Everyday words, used a little more precisely.',
  'subSkills': [
    for (final id in subSkills)
      {
        'id': id,
        'preAssessmentBank': [
          for (var q = 1; q <= bankSize; q++) _question('l$level-$id-pre-$q'),
        ],
        'postAssessmentBank': [
          for (var q = 1; q <= bankSize; q++) _question('l$level-$id-post-$q'),
        ],
      },
  ],
  'chunks': [
    for (final id in subSkills)
      {
        'id': 'l$level-$id-1',
        'subSkillId': id,
        'title': 'Chunk for $id',
        'words': [_fullCard, _bareCard],
        'practice': [_question('l$level-$id-practice-1')],
      },
  ],
};

/// Every optional field filled in.
const _fullCard = {
  'word': 'reluctant',
  'bn': 'অনিচ্ছুক',
  'pos': 'adjective',
  'example': {
    'en': 'He was reluctant to accept the offer.',
    'bn': 'সে প্রস্তাবটি নিতে অনিচ্ছুক ছিল।',
  },
  'usage': 'reluctant + to + verb',
  'synonyms': ['unwilling', 'hesitant'],
  'antonyms': ['willing', 'eager'],
  'collocations': ['reluctant to agree'],
};

/// Only what SPEC §8 makes mandatory — the case that proves a writer is not
/// forced to pad a simple word with sections it does not need.
const _bareCard = {
  'word': 'busy',
  'bn': 'ব্যস্ত',
  'example': {'en': 'The road was busy.', 'bn': 'রাস্তাটি ব্যস্ত ছিল।'},
};

Map<String, dynamic> _question(String id) => {
  'id': id,
  'type': 'collocation',
  'instruction': 'Choose one.',
  'prompt': 'Prompt for $id',
  'options': [
    for (var i = 0; i < 4; i++)
      {
        'id': '$id-${String.fromCharCode(97 + i)}',
        'text': 'Option ${String.fromCharCode(97 + i)}',
        'correct': i == 0,
      },
  ],
};
