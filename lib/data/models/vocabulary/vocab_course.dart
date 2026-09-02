import 'package:json_annotation/json_annotation.dart';

part 'vocab_course.g.dart';

/// A vocabulary competency, e.g. Collocations (SPEC §2).
///
/// The same six appear at every level; what changes is the words and the
/// contexts. Named to the learner on the result profile and the plan — never
/// on a question, where saying "this one measures Collocations" steers the
/// answer and measures the wrong thing.
@JsonSerializable(createToJson: false)
class VocabSubSkill {
  const VocabSubSkill({required this.id, required this.title});

  factory VocabSubSkill.fromJson(Map<String, dynamic> json) =>
      _$VocabSubSkillFromJson(json);

  final String id;
  final String title;
}

/// How the adaptive level check climbs, stops, or asks for more (SPEC §3).
///
/// Every threshold is authored rather than coded, so tuning the check after
/// watching real learners is a content edit.
@JsonSerializable(createToJson: false)
class LadderConfig {
  const LadderConfig({
    required this.questionsPerSubSkill,
    required this.advanceAt,
    required this.probeAt,
    required this.probeSize,
    required this.probeAdvanceAt,
    required this.topLevel,
  });

  factory LadderConfig.fromJson(Map<String, dynamic> json) =>
      _$LadderConfigFromJson(json);

  /// Drawn from each subskill's bank at each level, so a level check covers
  /// every subskill (SPEC §3).
  final int questionsPerSubSkill;

  /// Score at a level that sends the learner up to the next one.
  final int advanceAt;

  /// Score that buys more evidence instead of deciding. Below it the ladder
  /// stops here: one unlucky answer should not set someone's level, and
  /// neither should one lucky one.
  final int probeAt;

  /// Extra questions the probe draws, from the subskills that were missed.
  final int probeSize;

  /// How many of those must be right to still advance.
  final int probeAdvanceAt;

  /// The highest authored level. Adding Level 5 means new content and this
  /// number — no code.
  final int topLevel;
}

/// How the final check is assembled (SPEC §15, §16).
@JsonSerializable(createToJson: false)
class FinalCheckConfig {
  const FinalCheckConfig({
    required this.basePerSubSkill,
    required this.extraPerFocus,
  });

  factory FinalCheckConfig.fromJson(Map<String, dynamic> json) =>
      _$FinalCheckConfigFromJson(json);

  /// Asked about every subskill, taught or not — evidence that nothing was
  /// lost while the learner was working elsewhere.
  final int basePerSubSkill;

  /// Added for each subskill the plan actually taught. The improvement claim
  /// rests on these, and one question could not carry it (SPEC §5).
  final int extraPerFocus;
}

/// The vocabulary module's shape: what is measured, and how the check
/// decides. Levels are authored as separate files and read on demand.
@JsonSerializable(createToJson: false)
class VocabCourse {
  const VocabCourse({
    required this.subSkills,
    required this.ladder,
    required this.finalCheck,
  });

  factory VocabCourse.fromJson(Map<String, dynamic> json) =>
      _$VocabCourseFromJson(json);

  final List<VocabSubSkill> subSkills;
  final LadderConfig ladder;
  final FinalCheckConfig finalCheck;

  /// Questions in one full level check, before any probe.
  int get checkLength => subSkills.length * ladder.questionsPerSubSkill;

  VocabSubSkill subSkill(String id) => subSkills.firstWhere((s) => s.id == id);

  /// The subskills named by [ids], in authored order. Unknown ids drop out —
  /// stored progress outlives content edits.
  List<VocabSubSkill> subSkillsNamed(Iterable<String> ids) {
    final wanted = ids.toSet();
    return [
      for (final s in subSkills)
        if (wanted.contains(s.id)) s,
    ];
  }
}
