import 'package:flutter/foundation.dart';

import '../../../data/models/assessment_paper.dart';
import '../../../data/models/assessment_result.dart';

/// Where a pre-assessment is.
enum AssessmentStatus {
  /// The topic is still being read.
  loading,

  /// The topic could not be read, or has nothing to ask.
  failed,

  /// A paper is dealt and the learner is working through it.
  inProgress,

  /// Every question is behind them and [AssessmentState.result] is set.
  finished,
}

/// Everything the pre-assessment screens draw from.
///
/// Immutable, like the sign-in state before it: a rebuild can only come from
/// the view model assigning new state, never from a widget reaching in.
@immutable
class AssessmentState {
  const AssessmentState({
    this.status = AssessmentStatus.loading,
    this.paper,
    this.index = 0,
    this.answers = const {},
    this.result,
    this.error,
  });

  final AssessmentStatus status;

  /// The dealt paper. Null until the topic has loaded.
  final AssessmentPaper? paper;

  /// Which question is on screen, zero-based.
  final int index;

  /// Question id to chosen option id. Absent means not yet answered — and,
  /// if the paper is scored anyway, wrong.
  final Map<String, String> answers;

  /// Set once, when the last question is answered.
  final AssessmentResult? result;

  /// Learner-facing wording, already phrased for display.
  final String? error;

  int get total => paper?.length ?? 0;

  DrawnQuestion? get current => (paper == null || index < 0 || index >= total)
      ? null
      : paper!.questions[index];

  /// One-based, for "Question 3 of 15". Zero when there is no paper, so it
  /// never reads as "Question 1" of nothing.
  int get position => total == 0 ? 0 : index + 1;

  double get progress => total == 0 ? 0 : position / total;

  bool get isLast => total > 0 && index == total - 1;

  String? get selectedOptionId {
    final question = current;
    return question == null ? null : answers[question.id];
  }

  /// Advancing needs an answer: a diagnostic that lets people click past
  /// questions measures patience, not English.
  bool get canAdvance => selectedOptionId != null;

  bool get canGoBack => index > 0;

  int get answeredCount => answers.length;

  /// Distinguishes "leave this alone" from "set it to null", which a plain
  /// nullable parameter cannot do.
  static const _keep = Object();

  AssessmentState copyWith({
    AssessmentStatus? status,
    AssessmentPaper? paper,
    int? index,
    Map<String, String>? answers,
    Object? result = _keep,
    Object? error = _keep,
  }) {
    return AssessmentState(
      status: status ?? this.status,
      paper: paper ?? this.paper,
      index: index ?? this.index,
      answers: answers ?? this.answers,
      result: identical(result, _keep)
          ? this.result
          : result as AssessmentResult?,
      error: identical(error, _keep) ? this.error : error as String?,
    );
  }
}
