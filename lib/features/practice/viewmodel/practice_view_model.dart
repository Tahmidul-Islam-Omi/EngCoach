import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/topic.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../model/practice_state.dart';

/// Which lesson's practice this is.
typedef PracticeKey = ({String topicId, String subSkillId});

/// Runs the practice questions for one lesson.
///
/// Holds no widgets and touches no context, so the whole flow — choosing,
/// revealing, moving on — is testable without a device.
///
/// Not auto-disposing, for the same reason the pre-assessment is not: the
/// summary is a state of this flow, not a separate screen. The screen clears
/// it on entry instead.
class PracticeViewModel extends Notifier<PracticeState> {
  PracticeViewModel(this.key);

  final PracticeKey key;

  /// Kept so [restart] can re-shuffle without reloading the topic.
  Topic? _topic;

  @override
  PracticeState build() {
    final topic = ref.watch(topicProvider(key.topicId));

    return switch (topic) {
      AsyncData(:final value) => _start(value),
      AsyncError() => const PracticeState(
          status: PracticeStatus.failed,
          error: "This lesson couldn't be loaded. Check your connection.",
        ),
      _ => const PracticeState(),
    };
  }

  PracticeState _start(Topic topic) {
    _topic = topic;

    final lesson =
        topic.lessons.where((l) => l.subSkillId == key.subSkillId).firstOrNull;

    if (lesson == null || lesson.practice.isEmpty) {
      return const PracticeState(
        status: PracticeStatus.failed,
        error: 'This lesson has no practice yet.',
      );
    }

    final random = Random();

    return PracticeState(
      status: PracticeStatus.inProgress,
      items: [
        for (final question in lesson.practice)
          PracticeItem(
            question: question,
            // Shuffled per learner, so the answer's position is never
            // something to memorise between attempts.
            options: List.of(question.options)..shuffle(random),
          ),
      ],
    );
  }

  /// Records the answer and reveals it. Choosing again does nothing — the
  /// explanation is already on screen, and letting them switch would turn
  /// practice into guessing until it goes green.
  void choose(String optionId) {
    final item = state.current;
    if (item == null ||
        state.status != PracticeStatus.inProgress ||
        state.revealed) {
      return;
    }

    state = state.copyWith(
      chosenOptionId: optionId,
      answers: {...state.answers, item.question.id: optionId},
    );
  }

  /// Moves on, or finishes. Only available once they have answered, so
  /// nothing can be skipped past unread.
  void next() {
    if (state.status != PracticeStatus.inProgress || !state.revealed) return;

    if (state.isLast) {
      state = state.copyWith(status: PracticeStatus.finished);
      // Finishing the practice is what marks the sub-skill done — reading
      // the lesson alone is attendance, not evidence.
      unawaited(_recordCompletion());
      return;
    }

    state = state.copyWith(
      index: state.index + 1,
      chosenOptionId: null,
    );
  }

  /// Records the completion and refreshes the plan, so returning to it
  /// shows this lesson ticked off.
  ///
  /// Not awaited by the caller: the summary is already on screen, and a slow
  /// connection must not hold it. Firestore queues the write offline.
  Future<void> _recordCompletion() async {
    try {
      await ref.read(progressRepositoryProvider).markSubSkillComplete(
            topicId: key.topicId,
            subSkillId: key.subSkillId,
          );
      ref.invalidate(topicProgressProvider(key.topicId));
    } catch (_) {
      // Nothing useful to tell the learner: they did the work either way,
      // and the write retries. Reported once Crashlytics is in.
    }
  }

  /// Same questions, freshly shuffled and unanswered.
  void restart() {
    final topic = _topic;
    if (topic == null) return;

    state = _start(topic);
  }

  /// After a load failure.
  void retry() => ref.invalidate(topicProvider(key.topicId));
}

final practiceViewModelProvider = NotifierProvider.family<PracticeViewModel,
    PracticeState, PracticeKey>(PracticeViewModel.new);
