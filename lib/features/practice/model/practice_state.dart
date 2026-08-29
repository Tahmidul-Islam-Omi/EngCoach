import 'package:flutter/foundation.dart';

import '../../../data/models/question.dart';

/// One practice question as this learner sees it.
@immutable
class PracticeItem {
  const PracticeItem({required this.question, required this.options});

  final Question question;

  /// [Question.options] in this learner's order. A separate list, because
  /// content is parsed once and cached — shuffling the model's own list
  /// would reorder it for everyone.
  final List<QuestionOption> options;

  String get correctOptionId => question.correctOption.id;
}

enum PracticeStatus {
  loading,
  failed,

  /// A question is on screen, answered or not.
  inProgress,

  /// All questions are behind them.
  finished,
}

/// Everything the practice screen draws from.
///
/// Practice differs from an assessment in one way that shapes all of this:
/// the answer is revealed the moment it is chosen, with the authored
/// explanation for whatever they picked. The assessment measures; this
/// teaches (SPEC §6, Phase 2).
@immutable
class PracticeState {
  const PracticeState({
    this.status = PracticeStatus.loading,
    this.items = const [],
    this.index = 0,
    this.chosenOptionId,
    this.answers = const {},
    this.error,
  });

  final PracticeStatus status;
  final List<PracticeItem> items;
  final int index;

  /// What they picked for the question on screen. Null until they pick,
  /// which is also what "not revealed yet" means.
  final String? chosenOptionId;

  /// Question id to chosen option id, for the closing count.
  final Map<String, String> answers;

  final String? error;

  int get total => items.length;

  PracticeItem? get current =>
      (index < 0 || index >= total) ? null : items[index];

  /// One-based, for "Question 2 of 3".
  int get position => index + 1;

  bool get isLast => total > 0 && index == total - 1;

  /// The answer is shown as soon as something is chosen — there is no
  /// separate "check" step to tap through.
  bool get revealed => chosenOptionId != null;

  bool get isCorrect =>
      revealed && chosenOptionId == current?.correctOptionId;

  QuestionOption? get chosenOption {
    final id = chosenOptionId;
    if (id == null) return null;
    return current?.options.where((o) => o.id == id).firstOrNull;
  }

  int get correctCount {
    var right = 0;
    for (final item in items) {
      if (answers[item.question.id] == item.correctOptionId) right++;
    }
    return right;
  }

  /// Distinguishes "leave this alone" from "set it to null", which a plain
  /// nullable parameter cannot do.
  static const _keep = Object();

  PracticeState copyWith({
    PracticeStatus? status,
    List<PracticeItem>? items,
    int? index,
    Object? chosenOptionId = _keep,
    Map<String, String>? answers,
    Object? error = _keep,
  }) {
    return PracticeState(
      status: status ?? this.status,
      items: items ?? this.items,
      index: index ?? this.index,
      chosenOptionId: identical(chosenOptionId, _keep)
          ? this.chosenOptionId
          : chosenOptionId as String?,
      answers: answers ?? this.answers,
      error: identical(error, _keep) ? this.error : error as String?,
    );
  }
}
