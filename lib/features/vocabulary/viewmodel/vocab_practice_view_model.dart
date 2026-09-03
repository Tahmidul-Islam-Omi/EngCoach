import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/models/vocabulary/vocab_level.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../model/vocab_practice_state.dart';
import 'vocab_plan_view_model.dart';

/// Which word set's practice this is.
typedef VocabPracticeKey = ({int level, String chunkId});

/// Runs the practice questions for one word set.
///
/// Holds no widgets and touches no context, so the whole flow — choosing,
/// revealing, moving on — is testable without a device.
///
/// Not auto-disposing, for the same reason the check is not: the summary is a
/// state of this flow, not a separate screen. The screen clears it on entry.
class VocabPracticeViewModel extends Notifier<VocabPracticeState> {
  VocabPracticeViewModel(this.key);

  final VocabPracticeKey key;

  /// Kept so [restart] can re-shuffle without reloading the level.
  VocabChunk? _chunk;

  @override
  VocabPracticeState build() {
    final level = ref.watch(vocabLevelProvider(key.level));

    return switch (level) {
      AsyncData(:final value) => _start(value),
      AsyncError() => const VocabPracticeState(
        status: VocabPracticeStatus.failed,
        error: "This practice couldn't be loaded. Check your connection.",
      ),
      _ => const VocabPracticeState(),
    };
  }

  VocabPracticeState _start(VocabLevel level) {
    final chunk = level.chunks.where((c) => c.id == key.chunkId).firstOrNull;

    if (chunk == null || chunk.practice.isEmpty) {
      return const VocabPracticeState(
        status: VocabPracticeStatus.failed,
        error: 'This word set has no practice yet.',
      );
    }

    _chunk = chunk;
    return _deal(chunk);
  }

  /// How many questions a set carries is authored per chunk rather than fixed
  /// (SPEC §11): a set on phrasal verbs earns more than one on plurals.
  VocabPracticeState _deal(VocabChunk chunk) {
    final random = Random();

    return VocabPracticeState(
      status: VocabPracticeStatus.inProgress,
      chunkTitle: chunk.title,
      items: [
        for (final question in chunk.practice)
          VocabPracticeItem(
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
        state.status != VocabPracticeStatus.inProgress ||
        state.revealed) {
      return;
    }

    state = state.copyWith(
      chosenOptionId: optionId,
      answers: {...state.answers, item.question.id: optionId},
    );
  }

  /// Moves on, or finishes. Only available once they have answered, so nothing
  /// can be skipped past unread.
  void next() {
    if (state.status != VocabPracticeStatus.inProgress || !state.revealed) {
      return;
    }

    if (state.isLast) {
      state = state.copyWith(status: VocabPracticeStatus.finished);
      // Finishing marks the set done, whatever the score. A wrong answer
      // produces the authored explanation, which is itself a teaching moment
      // — so getting it wrong is still doing the work. Whether any of it
      // landed is the final check's question, not this one's (SPEC §12).
      ref.read(vocabPlanProvider.notifier).markChunkComplete(key.chunkId);
      return;
    }

    state = state.copyWith(index: state.index + 1, chosenOptionId: null);
  }

  /// Same questions, freshly shuffled and unanswered.
  void restart() {
    final chunk = _chunk;
    if (chunk == null) return;

    state = _deal(chunk);
  }

  /// After a load failure.
  void retry() => ref.invalidate(vocabLevelProvider(key.level));
}

final vocabPracticeViewModelProvider =
    NotifierProvider.family<
      VocabPracticeViewModel,
      VocabPracticeState,
      VocabPracticeKey
    >(VocabPracticeViewModel.new);
