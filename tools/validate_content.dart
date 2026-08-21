// Validates authored curriculum before it reaches Firestore.
//
//   dart run tools/validate_content.dart
//
// Every check here exists because a real bug got through review. Reading
// JSON does not catch skewed answer positions, a post-test that is easier
// than the pre-test, or a test sentence copied from the lesson that teaches
// it — but all three make the improvement number meaningless.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final dir = Directory(args.isEmpty ? 'content' : args.first);
  if (!dir.existsSync()) {
    stderr.writeln('No such directory: ${dir.path}');
    exit(2);
  }

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stderr.writeln('No .json topics found under ${dir.path}');
    exit(2);
  }

  var failed = 0;
  for (final file in files) {
    final problems = <String>[];
    try {
      _validate(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          problems);
    } on FormatException catch (e) {
      problems.add('invalid JSON: ${e.message}');
    }

    if (problems.isEmpty) {
      stdout.writeln('ok    ${file.path}');
    } else {
      failed++;
      stdout.writeln('FAIL  ${file.path}');
      for (final p in problems) {
        stdout.writeln('        $p');
      }
    }
  }

  stdout.writeln('\n${files.length} topic(s), $failed failing');
  exit(failed == 0 ? 0 : 1);
}

const _blockTypes = {
  'text', 'pattern', 'table', 'examples', 'callout', 'bangla',
};

void _validate(Map<String, dynamic> topic, List<String> problems) {
  void fail(String m) => problems.add(m);

  // ---------------------------------------------------------------- config
  final config = topic['assessmentConfig'] as Map<String, dynamic>? ?? {};
  final draw = config['questionsPerSubSkill'] as int? ?? 0;
  final qualify = config['qualifyingScore'] as int? ?? 0;
  if (draw < 1) fail('assessmentConfig.questionsPerSubSkill must be >= 1');
  // The trap: lowering `draw` without lowering `qualify` makes qualifying
  // impossible, so nothing is ever skipped and nothing visibly breaks.
  if (qualify > draw) {
    fail('qualifyingScore ($qualify) exceeds questionsPerSubSkill ($draw) — '
        'no learner could ever qualify to skip a sub-skill');
  }

  final subSkills = (topic['subSkills'] as List?) ?? const [];
  final lessons = (topic['lessons'] as List?) ?? const [];
  if (subSkills.isEmpty) fail('topic has no subSkills');

  // Sentences a learner meets while LEARNING. Assessments must not reuse
  // them, or a correct answer may only mean the sentence was memorised.
  final taught = <String>{};
  for (final l in lessons.cast<Map<String, dynamic>>()) {
    for (final b in (l['blocks'] as List).cast<Map<String, dynamic>>()) {
      switch (b['type']) {
        case 'examples':
          for (final i in (b['items'] as List).cast<Map<String, dynamic>>()) {
            taught.add(_norm(i['text'] as String));
          }
        case 'table':
          for (final row in (b['rows'] as List).cast<List>()) {
            taught.addAll(row.cast<String>().map(_norm));
          }
      }
      if (!_blockTypes.contains(b['type'])) {
        fail('${l['id']}: unknown block type "${b['type']}"');
      }
    }
    if (!(l['blocks'] as List).any((b) => b['type'] == 'bangla')) {
      fail('${l['id']}: no bangla block');
    }
    for (final p in (l['practice'] as List).cast<Map<String, dynamic>>()) {
      for (final o in (p['options'] as List).cast<Map<String, dynamic>>()) {
        taught.add(_norm(o['text'] as String));
      }
      _checkOptions(p, requireFeedback: true, fail: fail);
    }
  }

  final withLessons = lessons.map((l) => l['subSkillId']).toSet();
  final ids = <String>{};

  // Counted per bank, not pooled. A learner sits the pre-assessment as its
  // own test, so the two banks have to be balanced independently — pooling
  // them lets a skewed pre-bank hide behind an opposite skew in the post.
  final answerPositions = {
    'pre-assessment': <String, int>{},
    'post-assessment': <String, int>{},
  };

  for (final s in subSkills.cast<Map<String, dynamic>>()) {
    final id = s['id'] as String;
    if (!withLessons.contains(id)) fail('$id: no lesson');

    final pre = (s['preAssessmentBank'] as List).cast<Map<String, dynamic>>();
    final post = (s['postAssessmentBank'] as List).cast<Map<String, dynamic>>();

    if (pre.length < draw) fail('$id: pre bank has ${pre.length}, need >= $draw');
    if (post.length < draw) fail('$id: post bank has ${post.length}, need >= $draw');

    // A post-test that is easier than the pre-test inflates every score.
    final preRules = _tally(pre);
    final postRules = _tally(post);
    if (!_sameTally(preRules, postRules)) {
      fail('$id: pre/post rule coverage differs — $preRules vs $postRules');
    }

    // A sentence a learner already met in the pre-test measures memory the
    // second time round, not learning — so the improvement figure, which is
    // the whole product claim, stops meaning anything. Both directions
    // matter: yesterday's correct answer reappearing as today's distractor
    // is the worst case of all.
    // Whichever half of a question carries its content is the half that
    // must not repeat. Sentence options carry it themselves; a gap-fill
    // choosing between "a" and "the" carries it in the prompt instead,
    // and its four options are a closed set both banks have to share.
    final preAnswers = {
      for (final q in pre)
        if (_memorable(_answer(q))) _norm(_answer(q)),
    };
    final prePrompts = {
      for (final q in pre)
        if (!_memorable(_answer(q))) _norm(q['prompt'] as String),
    };

    for (final q in post) {
      for (final o in (q['options'] as List).cast<Map<String, dynamic>>()) {
        if (preAnswers.contains(_norm(o['text'] as String))) {
          fail('${q['id']}: "${o['text']}" is already a correct answer in the '
              'pre-assessment bank');
        }
      }
      if (!_memorable(_answer(q)) &&
          prePrompts.contains(_norm(q['prompt'] as String))) {
        fail('${q['id']}: asks the same question as the pre-assessment bank');
      }
    }

    for (final entry in [(pre, 'pre-assessment'), (post, 'post-assessment')]) {
      for (final q in entry.$1) {
        final qid = q['id'] as String;
        if (!ids.add(qid)) fail('duplicate question id: $qid');
        if ((q['rule'] as String?)?.isEmpty ?? true) fail('$qid: missing rule tag');

        final options = (q['options'] as List).cast<Map<String, dynamic>>();
        for (final o in options) {
          final text = o['text'] as String;
          if (_memorable(text) && taught.contains(_norm(text))) {
            fail('$qid: option "$text" also appears in a lesson');
          }
        }
        _checkOptions(q,
            requireFeedback: entry.$2 == 'post-assessment', fail: fail);

        final correct = options.firstWhere((o) => o['correct'] == true,
            orElse: () => const {'id': '?'});
        answerPositions[entry.$2]!
            .update(correct['id'] as String, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }

  // If one letter dominates, a learner can score without reading. Four
  // options make 25% the honest rate; 35% leaves room for small banks
  // without letting a guessable pattern through.
  answerPositions.forEach((bank, counts) {
    if (counts.isEmpty) return;
    final total = counts.values.reduce((a, b) => a + b);
    final worst = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final share = worst.value / total;
    if (share > 0.35) {
      fail('$bank answers cluster on "${worst.key}" '
          '(${worst.value} of $total, ${(share * 100).round()}%) — guessing '
          'one letter would score too well');
    }
  });
}

void _checkOptions(
  Map<String, dynamic> q, {
  required bool requireFeedback,
  required void Function(String) fail,
}) {
  final qid = q['id'];
  final options = (q['options'] as List).cast<Map<String, dynamic>>();

  if (options.length != 4) fail('$qid: ${options.length} options, expected 4');

  final correct = options.where((o) => o['correct'] == true).length;
  if (correct != 1) fail('$qid: $correct correct answers, expected exactly 1');

  final texts = options.map((o) => _norm(o['text'] as String)).toSet();
  if (texts.length != options.length) fail('$qid: duplicate option text');

  // Feedback shared by error type saves authoring the same explanation
  // twice, but a shared message that quotes an example has to pick some
  // wh- word — and is then wrong for every question using a different one.
  // "Where had they..." shown under "Why had they cancelled the show?"
  // teaches the wrong correction.
  final asked = _asksWith(options);

  for (final o in options) {
    final fb = o['feedback'] as Map<String, dynamic>?;
    if (requireFeedback) {
      if (fb == null) {
        fail('$qid/${o['id']}: missing feedback');
      } else {
        if ((fb['en'] as String?)?.trim().isEmpty ?? true) {
          fail('$qid/${o['id']}: missing English feedback');
        }
        if ((fb['bn'] as String?)?.trim().isEmpty ?? true) {
          fail('$qid/${o['id']}: missing Bangla feedback');
        }
        if (asked.isNotEmpty) {
          for (final lang in ['en', 'bn']) {
            for (final named in _quotedWh(fb[lang] as String? ?? '')) {
              if (!asked.contains(named)) {
                fail('$qid/${o['id']}: $lang feedback quotes "$named" but '
                    'the question asks with ${asked.join(" / ")}');
              }
            }
          }
        }
      }
    } else if (fb != null) {
      // The pre-assessment deliberately shows nothing.
      fail('$qid/${o['id']}: pre-assessment options must not carry feedback');
    }
  }
}

/// Function words a gap-fill picks between, rather than content to learn.
const _closedSet = {'a', 'an', 'the', 'some', 'any', 'no article'};

/// Whether repeating this option would mean a learner could recognise it.
///
/// A gap-fill choosing between "a", "an", "the" and "some" has only four
/// possible answers, so every bank and every lesson is bound to share
/// them — flagging that is arithmetic, not a finding. Content words stay
/// checked, single ones included: "smiling" drilled in practice and then
/// used as a test answer is a real overlap.
bool _memorable(String option) => !_closedSet.contains(_norm(option));

const _wh = {'what', 'when', 'where', 'which', 'who', 'whose', 'why', 'how'};

/// The question word a wh- question asks with, or empty for other questions.
///
/// Only a *leading* word counts. "who" in "I'll see who it is" and "which"
/// in "shows which came first" are relative pronouns, not question words —
/// counting those made this check fire on correct content.
Set<String> _asksWith(List<Map<String, dynamic>> options) => options
    .map((o) => RegExp(r'[a-zA-Z]+').firstMatch(o['text'] as String)?[0])
    .whereType<String>()
    .map((w) => w.toLowerCase())
    .where(_wh.contains)
    .toSet();

/// Question words quoted inside a **bold** example in [text].
///
/// Bold is what marks a phrase as a model to copy, and copying the wrong
/// one is the actual failure. Ordinary prose mentioning "which" is fine.
Set<String> _quotedWh(String text) => RegExp(r'\*\*(.+?)\*\*')
    .allMatches(text)
    .expand((m) => RegExp(r'[a-zA-Z]+').allMatches(m[1]!))
    .map((m) => m[0]!.toLowerCase())
    .where(_wh.contains)
    .toSet();

/// The text of a question's correct option, or '' if it has none — the
/// missing-answer case is already reported by [_checkOptions].
String _answer(Map<String, dynamic> q) {
  final options = (q['options'] as List).cast<Map<String, dynamic>>();
  final correct = options.where((o) => o['correct'] == true);
  return correct.isEmpty ? '' : correct.first['text'] as String;
}

Map<String, int> _tally(List<Map<String, dynamic>> bank) {
  final out = <String, int>{};
  for (final q in bank) {
    out.update(q['rule'] as String? ?? '?', (n) => n + 1, ifAbsent: () => 1);
  }
  return out;
}

bool _sameTally(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp('[^a-z ]'), '').trim();
