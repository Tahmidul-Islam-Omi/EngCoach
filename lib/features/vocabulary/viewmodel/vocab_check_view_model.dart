import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vocabulary/vocab_ladder.dart';
import '../../../data/models/vocabulary/vocab_level.dart';
import '../../../data/models/vocabulary/vocab_paper.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/models/vocabulary/vocab_result.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../model/vocab_check_state.dart';
import 'vocab_plan_view_model.dart';

/// Walks a learner up the vocabulary ladder.
///
/// The engine can already decide what happens after a level is scored; this is
/// what acts on the decision — loading the next rung, dealing the probe, or
/// stopping and reading the profile.
///
/// Content is loaded imperatively rather than watched. Grammar can watch its
/// topic because a topic is fixed for the whole flow; here the level changes
/// as the learner climbs, and a watched family argument would mean rebuilding
/// the notifier mid-run and losing everything answered so far.
///
/// Not auto-disposing, for the same reason as the grammar assessment: the
/// result is a state of this flow and must survive the question screen. Whoever
/// enters the flow invalidates it.
class VocabCheckViewModel extends Notifier<VocabCheckState> {
  /// The rung this run opens on. Kept so a restart returns to it rather than
  /// dropping back to the bottom.
  int _from = 1;

  /// Question ids already asked at the level being checked, so the probe draws
  /// new evidence rather than a second look at the same item.
  final _askedAtLevel = <String>{};

  /// The subskills the probe will ask about, held between the borderline
  /// screen and the learner tapping through it.
  List<String> _pendingProbe = const [];

  VocabLevel? _levelContent;

  @override
  VocabCheckState build() {
    unawaited(_start());
    return const VocabCheckState();
  }

  Future<void> _start() async {
    try {
      final course = await ref.read(vocabularyRepositoryProvider).course();
      if (!ref.mounted) return;
      state = state.copyWith(course: course);

      _from = _openingLevel(await _plan(), course.ladder.topLevel);
      await _dealLevel(_from);
    } catch (_) {
      _fail("The vocabulary check couldn't be loaded. Check your connection.");
    }
  }

  /// Read once, never watched: settling writes the plan, and a watched plan
  /// would rebuild this mid-run and throw away everything answered so far.
  Future<VocabPlan?> _plan() async {
    try {
      return await ref.read(vocabPlanProvider.future);
    } catch (_) {
      return null;
    }
  }

  /// Where the ladder starts.
  ///
  /// Normally the bottom, because the ladder has no way down: starting high
  /// without evidence and then failing would settle a learner above where they
  /// belong. A level cleared by its final check is different — that is
  /// stronger evidence than the ladder's own six questions, and the level
  /// above it is exactly where the learner should now be studying. Failing
  /// there is not a misplacement; it means that level has a lot to teach.
  int _openingLevel(VocabPlan? plan, int topLevel) {
    if (plan == null) return 1;
    if (plan.after == null || !plan.isEmpty) return 1;

    return min(plan.level + 1, topLevel);
  }

  /// Loads a rung and deals its check.
  Future<void> _dealLevel(int level) async {
    state = state.copyWith(status: VocabCheckStatus.loading);

    final VocabLevel content;
    try {
      content = await ref.read(vocabularyRepositoryProvider).level(level);
    } catch (_) {
      _fail("Level $level couldn't be loaded. Check your connection.");
      return;
    }
    if (!ref.mounted) return;

    final course = state.course;
    if (course == null) return;

    final paper = VocabPaper.check(content, course);
    if (paper.isEmpty) {
      _fail('Level $level has no questions yet.');
      return;
    }

    _levelContent = content;
    _askedAtLevel
      ..clear()
      ..addAll(paper.questionIds);

    state = state.copyWith(
      status: VocabCheckStatus.inProgress,
      level: level,
      levelTitle: content.title,
      paper: paper,
      isProbe: false,
      index: 0,
      answers: const {},
    );
  }

  /// Records an answer to the question on screen. Choosing again replaces it —
  /// nothing is committed until the learner moves on.
  void select(String optionId) {
    final question = state.current;
    if (question == null || state.status != VocabCheckStatus.inProgress) return;

    state = state.copyWith(answers: {...state.answers, question.id: optionId});
  }

  /// Moves on, or scores the paper if this was the last question.
  void next() {
    if (state.status != VocabCheckStatus.inProgress || !state.canAdvance) {
      return;
    }

    if (state.isLast) {
      _score();
      return;
    }

    state = state.copyWith(index: state.index + 1);
  }

  /// Back one question within the current paper, keeping the answer so it can
  /// be changed rather than re-entered.
  void previous() {
    if (state.status != VocabCheckStatus.inProgress || !state.canGoBack) return;

    state = state.copyWith(index: state.index - 1);
  }

  /// Leaves the borderline screen and deals the extra questions it announced.
  void continueToProbe() {
    if (state.status != VocabCheckStatus.borderline) return;

    final content = _levelContent;
    final course = state.course;
    if (content == null || course == null) return;

    final paper = VocabPaper.probe(
      content,
      subSkillIds: _pendingProbe,
      size: course.ladder.probeSize,
      exclude: _askedAtLevel,
    );

    // A bank with nothing left to draw is an authoring fault the validator
    // catches. At runtime, decide on the evidence already in hand rather than
    // stranding the learner on a screen with no questions.
    if (paper.isEmpty) {
      _settle(state.level);
      return;
    }

    _askedAtLevel.addAll(paper.questionIds);

    state = state.copyWith(
      status: VocabCheckStatus.inProgress,
      paper: paper,
      isProbe: true,
      index: 0,
      answers: const {},
    );
  }

  /// Starts the run again from the level it opened on, with a fresh draw.
  void restart() {
    _askedAtLevel.clear();
    _pendingProbe = const [];
    _levelContent = null;
    state = VocabCheckState(course: state.course, level: _from);
    unawaited(_dealLevel(_from));
  }

  /// After a load failure.
  void retry() {
    state = const VocabCheckState();
    unawaited(_start());
  }

  void _score() {
    final paper = state.paper;
    final course = state.course;
    if (paper == null || course == null) return;

    final result = VocabLevelResult.score(paper, state.answers);
    final history = [...state.history, result];
    state = state.copyWith(history: history);

    final ladder = VocabLadder(course.ladder);
    final decision = state.isProbe
        ? ladder.afterProbe(result)
        : ladder.afterCheck(result);

    switch (decision) {
      case ClimbTo(:final level):
        unawaited(_dealLevel(level));
      case ProbeHere(:final subSkillIds):
        _pendingProbe = subSkillIds;
        state = state.copyWith(status: VocabCheckStatus.borderline);
      case SettleAt(:final level):
        _settle(level);
    }
  }

  void _settle(int level) {
    final course = state.course;
    if (course == null) return;

    final profile = VocabProfile.of(
      course: course,
      results: state.history,
      level: level,
    );

    state = state.copyWith(
      status: VocabCheckStatus.finished,
      level: level,
      paper: null,
      profile: profile,
    );

    // The plan outlives this flow, so it is handed over rather than read back
    // out of a view model the next screen has no business knowing about.
    // Not awaited: the result is already on screen, and Firestore queues the
    // write offline.
    unawaited(ref.read(vocabPlanProvider.notifier).adopt(profile));
  }

  void _fail(String message) {
    if (!ref.mounted) return;
    state = state.copyWith(status: VocabCheckStatus.failed, error: message);
  }
}

final vocabCheckViewModelProvider =
    NotifierProvider<VocabCheckViewModel, VocabCheckState>(
      VocabCheckViewModel.new,
    );
