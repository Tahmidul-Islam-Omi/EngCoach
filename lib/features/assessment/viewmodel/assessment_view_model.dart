import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/topic.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/models/assessment_paper.dart';
import '../../../data/models/assessment_result.dart';
import '../model/assessment_state.dart';

/// Which assessment this is: the diagnostic, or the one that proves it
/// worked.
typedef AssessmentKey = ({String topicId, AssessmentPhase phase});

/// Runs one topic's assessment, in either phase.
///
/// Holds no widgets and touches no context, so the whole flow — dealing,
/// answering, going back, scoring — is testable without a device.
///
/// Not auto-disposing on purpose: the result screen is pushed after the
/// question screen pops, and an auto-disposing provider would throw the
/// score away in between. Whoever leaves the flow invalidates it.
class AssessmentViewModel extends Notifier<AssessmentState> {
  AssessmentViewModel(this.key);

  final AssessmentKey key;

  String get topicId => key.topicId;

  /// Kept so [retake] can deal a fresh paper without reloading the topic.
  Topic? _topic;

  @override
  AssessmentState build() {
    // Watched, not read: the topic arrives asynchronously, and this rebuilds
    // when it does. That also means a topic reload restarts the assessment —
    // which only happens before answering, since nothing invalidates content
    // mid-flow.
    final topic = ref.watch(topicProvider(topicId));

    return switch (topic) {
      AsyncData(:final value) => _deal(value),
      AsyncError() => const AssessmentState(
          status: AssessmentStatus.failed,
          error: "This topic couldn't be loaded. Check your connection.",
        ),
      _ => const AssessmentState(),
    };
  }

  AssessmentState _deal(Topic topic) {
    _topic = topic;
    // The post-assessment draws from the other bank — different questions
    // covering the same rules in the same proportion, which is what makes
    // the two scores comparable at all.
    final paper = AssessmentPaper.draw(topic, phase: key.phase);

    if (paper.isEmpty) {
      return const AssessmentState(
        status: AssessmentStatus.failed,
        error: 'This topic has no assessment yet.',
      );
    }

    return AssessmentState(
      status: AssessmentStatus.inProgress,
      paper: paper,
    );
  }

  /// Records an answer to the question on screen. Choosing again replaces
  /// it — nothing is committed until the learner moves on.
  void select(String optionId) {
    final question = state.current;
    if (question == null || state.status != AssessmentStatus.inProgress) {
      return;
    }

    state = state.copyWith(
      answers: {...state.answers, question.id: optionId},
    );
  }

  /// Moves on, or scores the paper if this was the last question.
  void next() {
    if (state.status != AssessmentStatus.inProgress || !state.canAdvance) {
      return;
    }

    if (state.isLast) {
      _score();
      return;
    }

    state = state.copyWith(index: state.index + 1);
  }

  /// Back one question, keeping the answer so it can be changed rather than
  /// re-entered.
  void previous() {
    if (state.status != AssessmentStatus.inProgress || !state.canGoBack) {
      return;
    }

    state = state.copyWith(index: state.index - 1);
  }

  /// Deals a new paper over the same topic. The draw is random, so a retake
  /// is a different set of questions, not the same one memorised.
  void retake() {
    final topic = _topic;
    if (topic == null) return;

    state = _deal(topic);
  }

  /// After a load failure. Rebuilds through [build] once the topic reloads.
  void retry() => ref.invalidate(topicProvider(topicId));

  void _score() {
    final paper = state.paper;
    if (paper == null) return;

    final result = AssessmentResult.score(paper, state.answers);

    state = state.copyWith(
      status: AssessmentStatus.finished,
      result: result,
    );

    // Deliberately not awaited: the learner sees their result immediately,
    // and a slow connection must not hold the screen. Firestore queues the
    // write offline and sends it when the network returns.
    unawaited(_save(result));
  }

  Future<void> _save(AssessmentResult result) async {
    try {
      await ref.read(progressRepositoryProvider).saveAssessment(result);
    } catch (_) {
      // Nothing useful to tell the learner: the result is on screen, and
      // Firestore retries the write itself. Reported once Crashlytics is in.
    } finally {
      // Whatever reads progress next — the plan, the topic overview, the
      // topic list — must see this result rather than the cached answer
      // from before it. In a finally because a failed write still leaves
      // Firestore's local cache updated.
      ref.invalidate(topicProgressProvider(result.topicId));
    }
  }
}

final assessmentViewModelProvider = NotifierProvider.family<
    AssessmentViewModel, AssessmentState, AssessmentKey>(
  AssessmentViewModel.new,
);
