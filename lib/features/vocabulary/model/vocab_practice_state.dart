import 'package:flutter/foundation.dart';

import '../../../data/models/question.dart';
import '../../../data/models/vocabulary/vocab_question.dart';

/// One practice question as this learner sees it.
@immutable
class VocabPracticeItem {
  const VocabPracticeItem({required this.question, required this.options});

  final VocabQuestion question;

  /// [VocabQuestion.options] in this learner's order. A separate list, because
  /// content is parsed once and cached — shuffling the model's own list would
  /// reorder it for everyone.
  final List<QuestionOption> options;

  String get correctOptionId => question.correctOption.id;
}

enum VocabPracticeStatus {
  loading,
  failed,

  /// A question is on screen, answered or not.
  inProgress,

  /// All questions are behind them.
  finished,
}

/// Everything the vocabulary practice screen draws from.
///
/// Practice differs from the check in one way that shapes all of this: the
/// answer is revealed the moment it is chosen, with the authored explanation
/// for whatever they picked. The check measures; this teaches (SPEC §12).
@immutable
class VocabPracticeState {
  const VocabPracticeState({
    this.status = VocabPracticeStatus.loading,
    this.chunkTitle,
    this.items = const [],
    this.index = 0,
    this.chosenOptionId,
    this.answers = const {},
    this.error,
  });

  final VocabPracticeStatus status;

  /// The word set being practised, for the heading.
  final String? chunkTitle;

  final List<VocabPracticeItem> items;
  final int index;

  /// What they picked for the question on screen. Null until they pick, which
  /// is also what "not revealed yet" means.
  final String? chosenOptionId;

  /// Question id to chosen option id, for the closing count.
  final Map<String, String> answers;

  final String? error;

  int get total => items.length;

  VocabPracticeItem? get current =>
      (index < 0 || index >= total) ? null : items[index];

  /// One-based, for "Question 2 of 5".
  int get position => index + 1;

  bool get isLast => total > 0 && index == total - 1;

  /// The answer is shown as soon as something is chosen — there is no separate
  /// "check" step to tap through.
  bool get revealed => chosenOptionId != null;

  bool get isCorrect => revealed && chosenOptionId == current?.correctOptionId;

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

  VocabPracticeState copyWith({
    VocabPracticeStatus? status,
    String? chunkTitle,
    List<VocabPracticeItem>? items,
    int? index,
    Object? chosenOptionId = _keep,
    Map<String, String>? answers,
    Object? error = _keep,
  }) {
    return VocabPracticeState(
      status: status ?? this.status,
      chunkTitle: chunkTitle ?? this.chunkTitle,
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
