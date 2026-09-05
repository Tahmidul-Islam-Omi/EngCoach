import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vocabulary/vocab_plan.dart';
import '../models/vocabulary/vocab_result.dart';
import '../services/session_service.dart';

/// One area's score, flattened for storage.
///
/// Stored as a list rather than a map keyed by subskill id: Firestore map keys
/// cannot be indexed or ordered, and the authored order matters when these are
/// drawn side by side on the outcome screen.
@visibleForTesting
Map<String, Object?> scoreToMap(VocabSubSkillScore s) => {
  'id': s.subSkillId,
  'correct': s.correct,
  'total': s.total,
};

@visibleForTesting
List<VocabSubSkillScore> scoresFrom(Object? raw) => [
  if (raw is List)
    for (final entry in raw)
      if (entry is Map)
        VocabSubSkillScore(
          subSkillId: entry['id'] as String? ?? '',
          correct: (entry['correct'] as num?)?.toInt() ?? 0,
          total: (entry['total'] as num?)?.toInt() ?? 0,
        ),
];

/// The document a plan is stored as.
///
/// Pure and separate so the shape can be checked without Firestore, the way
/// grammar's `planUpdate` is.
@visibleForTesting
Map<String, Object?> planToMap(VocabPlan plan) => {
  'level': plan.level,
  'focusSubSkills': plan.focusSubSkillIds,
  'completedChunks': plan.completedChunkIds,
  'before': [for (final s in plan.before) scoreToMap(s)],
  if (plan.after case final after?)
    'after': [for (final s in after) scoreToMap(s)],
};

@visibleForTesting
VocabPlan? planFrom(Map<String, dynamic>? data) {
  if (data == null) return null;

  final level = (data['level'] as num?)?.toInt();
  // A document with no level is not a plan — it is a half-written record from
  // a write that failed between fields, and treating it as one would put the
  // learner on Level 0.
  if (level == null) return null;

  return VocabPlan(
    level: level,
    focusSubSkillIds:
        (data['focusSubSkills'] as List?)?.cast<String>() ?? const [],
    completedChunkIds:
        (data['completedChunks'] as List?)?.cast<String>() ?? const [],
    before: scoresFrom(data['before']),
    after: data['after'] == null ? null : scoresFrom(data['after']),
  );
}

/// Reads and writes the learner's vocabulary plan.
abstract interface class VocabProgressRepository {
  Future<VocabPlan?> plan();

  /// Replaces the plan wholesale. A check is a new diagnosis, not an
  /// amendment: the level may have moved, and sets finished at a different
  /// level are meaningless against it.
  Future<void> savePlan(VocabPlan plan);

  /// Records that one word set's practice is finished.
  Future<void> markChunkComplete(String chunkId);
}

/// Firestore, under `users/{phone}/sections/vocabulary`.
///
/// One document rather than a subcollection: vocabulary is a single course
/// with one level and one plan at a time, unlike grammar's six independent
/// topics. The path is the phone number, which is also the Firebase uid, so
/// the security rule stays `request.auth.uid == phone`.
class FirestoreVocabProgressRepository implements VocabProgressRepository {
  FirestoreVocabProgressRepository(this._firestore, this._session);

  final FirebaseFirestore _firestore;
  final SessionService _session;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final phone = _session.currentPhone;
    return phone == null
        ? null
        : _firestore
              .collection('users')
              .doc(phone)
              .collection('sections')
              .doc('vocabulary');
  }

  @override
  Future<VocabPlan?> plan() async {
    final doc = _doc;
    if (doc == null) return null;

    return planFrom((await doc.get()).data());
  }

  @override
  Future<void> savePlan(VocabPlan plan) async {
    final doc = _doc;
    // Signed out, or the token exchange failed. Losing a plan is bad, but a
    // crash mid-check is worse, and the gate makes this unreachable in normal
    // use.
    if (doc == null) return;

    // A plain set rather than a transaction, for the same reason grammar
    // writes this way: a transaction needs the network, so a check taken with
    // no signal would throw the result away instead of queueing it.
    //
    // Not merged, deliberately. A new plan replaces the old one, and merging
    // would leave the previous round's completed sets sitting under it.
    await doc.set({
      ...planToMap(plan),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> markChunkComplete(String chunkId) async {
    final doc = _doc;
    if (doc == null) return;

    await doc.set({
      // arrayUnion rather than a rewritten list, so two devices finishing
      // different sets offline both survive the merge.
      'completedChunks': FieldValue.arrayUnion([chunkId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }
}

final vocabProgressRepositoryProvider = Provider<VocabProgressRepository>(
  (ref) => FirestoreVocabProgressRepository(
    FirebaseFirestore.instance,
    ref.watch(sessionServiceProvider),
  ),
);
