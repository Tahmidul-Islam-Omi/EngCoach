import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the learner had got to in each word set.
///
/// Held above the screen because it is the one thing a word set must remember
/// when the learner leaves it. Kept as local widget state, closing the screen
/// reset the set to word one — so coming back to a set already read meant six
/// taps to reach the practice button again.
///
/// In memory only, and deliberately: this is a scroll position, not progress.
/// Losing it when the app restarts costs a learner nothing, and writing it to
/// Firestore on every card would be a network call per tap.
class VocabReadingPosition extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  int of(String chunkId) => state[chunkId] ?? 0;

  void moveTo(String chunkId, int index) {
    if (state[chunkId] == index) return;
    state = {...state, chunkId: index};
  }
}

final vocabReadingPositionProvider =
    NotifierProvider<VocabReadingPosition, Map<String, int>>(
      VocabReadingPosition.new,
    );
