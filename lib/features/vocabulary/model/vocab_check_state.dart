import 'package:flutter/foundation.dart';

import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_ladder.dart';
import '../../../data/models/vocabulary/vocab_paper.dart';
import '../../../data/models/vocabulary/vocab_result.dart';

/// Where the vocabulary check is.
///
/// One extra state compared with grammar's: [borderline]. The ladder can stop
/// mid-run and ask for more evidence, and the learner is told that is what is
/// happening rather than being handed two more questions without explanation.
enum VocabCheckStatus {
  /// The course or a level is still being read.
  loading,

  /// Content could not be read, or a level has nothing to ask.
  failed,

  /// A paper is dealt and the learner is working through it.
  inProgress,

  /// A level came back unclear. The probe is ready but not yet started.
  borderline,

  /// The ladder has settled and [VocabCheckState.profile] is set.
  finished,
}

/// Everything the vocabulary check screens draw from.
///
/// Immutable, like the grammar assessment state before it: a rebuild can only
/// come from the view model assigning new state, never from a widget reaching
/// in.
@immutable
class VocabCheckState {
  const VocabCheckState({
    this.status = VocabCheckStatus.loading,
    this.course,
    this.level = 1,
    this.levelTitle,
    this.paper,
    this.isProbe = false,
    this.index = 0,
    this.answers = const {},
    this.history = const [],
    this.profile,
    this.error,
  });

  final VocabCheckStatus status;

  /// The subskill registry and ladder thresholds. Null until loaded.
  final VocabCourse? course;

  /// The rung being checked right now.
  final int level;

  /// That rung's learner-facing name — "Foundation", "Developing". Held here
  /// because the result screen names the level after the content that
  /// produced it has gone out of scope.
  final String? levelTitle;

  /// The paper on screen — a level check, or the probe that follows one.
  final VocabPaper? paper;

  /// True while the learner is answering probe questions rather than a full
  /// level check. Changes how the paper is scored, not how it is shown.
  final bool isProbe;

  final int index;

  /// Question id to chosen option id. Absent means unanswered — and, if the
  /// paper is scored anyway, wrong.
  final Map<String, String> answers;

  /// Every paper scored on the way up, checks and probes alike. The profile
  /// is read from all of them, which is the repeated evidence SPEC §5 asks
  /// for and one paper cannot give.
  final List<VocabLevelResult> history;

  /// Set once the ladder settles.
  final VocabProfile? profile;

  /// Learner-facing wording, already phrased for display.
  final String? error;

  int get total => paper?.length ?? 0;

  VocabDrawn? get current => (paper == null || index < 0 || index >= total)
      ? null
      : paper!.questions[index];

  /// One-based, for "Question 3 of 6". Zero when there is no paper, so it
  /// never reads as "Question 1" of nothing.
  int get position => total == 0 ? 0 : index + 1;

  bool get isLast => total > 0 && index == total - 1;

  String? get selectedOptionId {
    final question = current;
    return question == null ? null : answers[question.id];
  }

  /// Advancing needs an answer: a check that lets people click past questions
  /// measures patience, not vocabulary.
  bool get canAdvance => selectedOptionId != null;

  /// Only within the current paper. Going back into a scored level would let
  /// a learner rewrite a decision the ladder has already made.
  bool get canGoBack => index > 0;

  /// Distinguishes "leave this alone" from "set it to null", which a plain
  /// nullable parameter cannot do.
  static const _keep = Object();

  VocabCheckState copyWith({
    VocabCheckStatus? status,
    VocabCourse? course,
    int? level,
    String? levelTitle,
    Object? paper = _keep,
    bool? isProbe,
    int? index,
    Map<String, String>? answers,
    List<VocabLevelResult>? history,
    Object? profile = _keep,
    Object? error = _keep,
  }) {
    return VocabCheckState(
      status: status ?? this.status,
      course: course ?? this.course,
      level: level ?? this.level,
      levelTitle: levelTitle ?? this.levelTitle,
      paper: identical(paper, _keep) ? this.paper : paper as VocabPaper?,
      isProbe: isProbe ?? this.isProbe,
      index: index ?? this.index,
      answers: answers ?? this.answers,
      history: history ?? this.history,
      profile: identical(profile, _keep)
          ? this.profile
          : profile as VocabProfile?,
      error: identical(error, _keep) ? this.error : error as String?,
    );
  }
}
