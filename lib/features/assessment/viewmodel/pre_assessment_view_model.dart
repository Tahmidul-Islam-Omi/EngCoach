import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/topic.dart';
import '../../../data/repositories/content_repository.dart';
import '../model/assessment_paper.dart';
import '../model/assessment_result.dart';
import '../model/pre_assessment_state.dart';

/// Runs one topic's pre-assessment.
///
/// Holds no widgets and touches no context, so the whole flow — dealing,
/// answering, going back, scoring — is testable without a device.
///
/// Not auto-disposing on purpose: the result screen is pushed after the
/// question screen pops, and an auto-disposing provider would throw the
/// score away in between. Whoever leaves the flow invalidates it.
class PreAssessmentViewModel extends Notifier<PreAssessmentState> {
  PreAssessmentViewModel(this.topicId);

  final String topicId;

  /// Kept so [retake] can deal a fresh paper without reloading the topic.
  Topic? _topic;

  @override
  PreAssessmentState build() {
    // Watched, not read: the topic arrives asynchronously, and this rebuilds
    // when it does. That also means a topic reload restarts the assessment —
    // which only happens before answering, since nothing invalidates content
    // mid-flow.
    final topic = ref.watch(topicProvider(topicId));

    return switch (topic) {
      AsyncData(:final value) => _deal(value),
      AsyncError() => const PreAssessmentState(
          status: PreAssessmentStatus.failed,
          error: "This topic couldn't be loaded. Check your connection.",
        ),
      _ => const PreAssessmentState(),
    };
  }

  PreAssessmentState _deal(Topic topic) {
    _topic = topic;
    final paper = AssessmentPaper.draw(topic);

    if (paper.isEmpty) {
      return const PreAssessmentState(
        status: PreAssessmentStatus.failed,
        error: 'This topic has no assessment yet.',
      );
    }

    return PreAssessmentState(
      status: PreAssessmentStatus.inProgress,
      paper: paper,
    );
  }

  /// Records an answer to the question on screen. Choosing again replaces
  /// it — nothing is committed until the learner moves on.
  void select(String optionId) {
    final question = state.current;
    if (question == null || state.status != PreAssessmentStatus.inProgress) {
      return;
    }

    state = state.copyWith(
      answers: {...state.answers, question.id: optionId},
    );
  }

  /// Moves on, or scores the paper if this was the last question.
  void next() {
    if (state.status != PreAssessmentStatus.inProgress || !state.canAdvance) {
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
    if (state.status != PreAssessmentStatus.inProgress || !state.canGoBack) {
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

    state = state.copyWith(
      status: PreAssessmentStatus.finished,
      result: AssessmentResult.score(paper, state.answers),
    );
  }
}

final preAssessmentViewModelProvider = NotifierProvider.family<
    PreAssessmentViewModel, PreAssessmentState, String>(
  PreAssessmentViewModel.new,
);
