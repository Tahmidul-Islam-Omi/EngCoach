import 'package:flutter/foundation.dart';

import 'vocab_course.dart';
import 'vocab_result.dart';

/// What the ladder does next after a level was scored (SPEC §3).
sealed class LadderDecision {
  const LadderDecision();
}

/// Strong enough here — try the level above.
final class ClimbTo extends LadderDecision {
  const ClimbTo(this.level);
  final int level;
}

/// Unclear. Buy a little more evidence before deciding, from the subskills
/// that were actually missed.
final class ProbeHere extends LadderDecision {
  const ProbeHere({required this.level, required this.subSkillIds});
  final int level;
  final List<String> subSkillIds;
}

/// This is the learner's level. Everything downstream — the plan, the
/// chunks, the final check — is built at this number.
final class SettleAt extends LadderDecision {
  const SettleAt(this.level);
  final int level;
}

/// The adaptive level check, as pure arithmetic over a scored paper.
///
/// Deliberately knows nothing about repositories, screens or storage: the
/// decision that sets a learner's level is the one piece of this module that
/// must be checkable by reading it, so it is a function of a score and six
/// authored numbers and nothing else.
@immutable
class VocabLadder {
  const VocabLadder(this.config);

  final LadderConfig config;

  /// The decision after a level's base questions.
  LadderDecision afterCheck(VocabLevelResult check) {
    if (check.correct >= config.advanceAt) return _up(check.level);
    if (check.correct >= config.probeAt) {
      return ProbeHere(level: check.level, subSkillIds: check.missed);
    }
    // Below the probe band the answer is not in doubt, so there is nothing
    // to buy. Extending here would also mean asking a learner who is
    // struggling to keep going — the opposite of what the score is saying.
    return SettleAt(check.level);
  }

  /// The decision after the probe questions the borderline score bought.
  ///
  /// The bar is the probe alone, not the combined total: the probe exists
  /// precisely because the base score was not decisive, so letting it back
  /// into the arithmetic would put the doubt back in.
  LadderDecision afterProbe(VocabLevelResult probe) =>
      probe.correct >= config.probeAdvanceAt
      ? _up(probe.level)
      : SettleAt(probe.level);

  /// Climbing off the top rung settles there instead — Level 5 is a content
  /// change, and until it exists the strongest learner belongs at the top.
  LadderDecision _up(int level) =>
      level >= config.topLevel ? SettleAt(config.topLevel) : ClimbTo(level + 1);
}

/// What the whole run says about the learner: their level, and where their
/// vocabulary is weakest (SPEC §6).
@immutable
class VocabProfile {
  const VocabProfile({
    required this.level,
    required this.subSkills,
    required this.focusSubSkillIds,
  });

  /// Reads a finished ladder run.
  ///
  /// [results] is every paper the learner sat on the way up, checks and
  /// probes alike. The per-subskill figures aggregate all of them — a learner
  /// who climbed to Level 3 answered each subskill three times, which is the
  /// repeated evidence SPEC §5 asks for and which one paper cannot give.
  ///
  /// Focus areas, though, come only from [level]: what someone missed at
  /// Level 1 on their way past it says nothing about what to teach them at
  /// Level 3, where the words are different. A learner who settled at the
  /// first rung has thin evidence by definition — practice and the final
  /// check are what firm it up.
  factory VocabProfile.of({
    required VocabCourse course,
    required Iterable<VocabLevelResult> results,
    required int level,
  }) {
    final totals = <String, VocabSubSkillScore>{};
    final missedHere = <String>{};

    for (final result in results) {
      for (final score in result.subSkills) {
        final id = score.subSkillId;
        totals[id] = totals[id]?.plus(score) ?? score;
        if (result.level == level && !score.clean) missedHere.add(id);
      }
    }

    // Driven by the course so the order is the authored one and a subskill
    // renamed since the run simply drops out.
    return VocabProfile(
      level: level,
      subSkills: List.unmodifiable([
        for (final s in course.subSkills) ?totals[s.id],
      ]),
      focusSubSkillIds: List.unmodifiable([
        for (final s in course.subSkills)
          if (missedHere.contains(s.id)) s.id,
      ]),
    );
  }

  final int level;

  /// Every subskill the learner was asked about, aggregated across the run.
  final List<VocabSubSkillScore> subSkills;

  /// What the plan teaches, in authored order — which is teaching order.
  final List<String> focusSubSkillIds;

  bool get allClear => focusSubSkillIds.isEmpty;

  VocabSubSkillScore? scoreFor(String subSkillId) {
    for (final s in subSkills) {
      if (s.subSkillId == subSkillId) return s;
    }
    return null;
  }
}
