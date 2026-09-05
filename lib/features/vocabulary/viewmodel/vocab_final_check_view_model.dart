import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_level.dart';
import '../../../data/models/vocabulary/vocab_paper.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/models/vocabulary/vocab_result.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import 'vocab_plan_view_model.dart';

/// Where the final check is.
enum VocabFinalStatus { loading, failed, inProgress, finished }

/// Everything the final check screen draws from.
///
/// Simpler than the ladder: one paper, scored once. The adaptive part has
/// already happened — the level is settled and the plan has been worked
/// through, so this only has to measure whether it landed.
class VocabFinalState {
  const VocabFinalState({
    this.status = VocabFinalStatus.loading,
    this.paper,
    this.index = 0,
    this.answers = const {},
    this.result,
    this.stillWeak = const [],
    this.error,
  });

  final VocabFinalStatus status;
  final VocabPaper? paper;
  final int index;
  final Map<String, String> answers;
  final VocabLevelResult? result;

  /// Areas the final check still found wanting, in authored order.
  final List<String> stillWeak;

  final String? error;

  int get total => paper?.length ?? 0;

  VocabDrawn? get current => (paper == null || index < 0 || index >= total)
      ? null
      : paper!.questions[index];

  int get position => total == 0 ? 0 : index + 1;

  bool get isLast => total > 0 && index == total - 1;

  String? get selectedOptionId {
    final question = current;
    return question == null ? null : answers[question.id];
  }

  bool get canAdvance => selectedOptionId != null;

  bool get canGoBack => index > 0;

  static const _keep = Object();

  VocabFinalState copyWith({
    VocabFinalStatus? status,
    VocabPaper? paper,
    int? index,
    Map<String, String>? answers,
    Object? result = _keep,
    List<String>? stillWeak,
    Object? error = _keep,
  }) => VocabFinalState(
    status: status ?? this.status,
    paper: paper ?? this.paper,
    index: index ?? this.index,
    answers: answers ?? this.answers,
    result: identical(result, _keep)
        ? this.result
        : result as VocabLevelResult?,
    stillWeak: stillWeak ?? this.stillWeak,
    error: identical(error, _keep) ? this.error : error as String?,
  );
}

/// Runs the check taken after the plan is finished.
///
/// Draws from the post bank — different sentences, the same words the lesson
/// taught — so the two scores can be set against each other at all.
///
/// The plan is read once rather than watched. Scoring rewrites it, and a
/// watched plan would rebuild this the moment that write landed — dealing a
/// fresh paper over the outcome the learner had just been shown, and putting
/// them back on question one of a check they had finished.
class VocabFinalCheckViewModel extends Notifier<VocabFinalState> {
  @override
  VocabFinalState build() {
    unawaited(_start());
    return const VocabFinalState();
  }

  Future<void> _start() async {
    final plan = await _plan();
    if (!ref.mounted) return;

    if (plan == null) {
      state = const VocabFinalState(
        status: VocabFinalStatus.failed,
        error: 'Take the check first.',
      );
      return;
    }

    final VocabCourse course;
    final VocabLevel level;
    try {
      course = await ref.read(vocabCourseProvider.future);
      level = await ref.read(vocabLevelProvider(plan.level).future);
    } catch (_) {
      if (!ref.mounted) return;
      state = const VocabFinalState(
        status: VocabFinalStatus.failed,
        error: "The final check couldn't be loaded. Check your connection.",
      );
      return;
    }
    if (!ref.mounted) return;

    state = _deal(course, level, plan);
  }

  Future<VocabPlan?> _plan() async {
    try {
      return await ref.read(vocabPlanProvider.future);
    } catch (_) {
      return null;
    }
  }

  VocabFinalState _deal(VocabCourse course, VocabLevel level, VocabPlan plan) {
    final paper = VocabPaper.finalCheck(
      level,
      course,
      focus: plan.focusSubSkillIds,
    );

    if (paper.isEmpty) {
      return const VocabFinalState(
        status: VocabFinalStatus.failed,
        error: 'This level has no final check yet.',
      );
    }

    return VocabFinalState(status: VocabFinalStatus.inProgress, paper: paper);
  }

  void select(String optionId) {
    final question = state.current;
    if (question == null || state.status != VocabFinalStatus.inProgress) return;

    state = state.copyWith(answers: {...state.answers, question.id: optionId});
  }

  void next() {
    if (state.status != VocabFinalStatus.inProgress || !state.canAdvance) {
      return;
    }

    if (state.isLast) {
      _score();
      return;
    }

    state = state.copyWith(index: state.index + 1);
  }

  void previous() {
    if (state.status != VocabFinalStatus.inProgress || !state.canGoBack) return;

    state = state.copyWith(index: state.index - 1);
  }

  void _score() {
    final paper = state.paper;
    if (paper == null) return;

    final result = VocabLevelResult.score(paper, state.answers);

    state = state.copyWith(
      status: VocabFinalStatus.finished,
      result: result,
      stillWeak: result.missed,
    );

    // The plan is rewritten around what this check found — the areas it still
    // flags replace the ones the first check named. Not awaited: the outcome
    // is already on screen, and Firestore queues the write offline.
    unawaited(
      ref
          .read(vocabPlanProvider.notifier)
          .recordFinalCheck(after: result.subSkills, stillWeak: result.missed),
    );
  }

  void retry() {
    state = const VocabFinalState();
    unawaited(_start());
  }
}

final vocabFinalCheckProvider =
    NotifierProvider<VocabFinalCheckViewModel, VocabFinalState>(
      VocabFinalCheckViewModel.new,
    );
