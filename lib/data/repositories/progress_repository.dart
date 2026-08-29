import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assessment_paper.dart';
import '../models/assessment_result.dart';
import '../models/topic_status.dart';
import '../services/session_service.dart';

/// What a learner has done with one topic.
class TopicProgress {
  const TopicProgress({
    required this.topicId,
    required this.status,
    this.weakSubSkills = const [],
    this.completedSubSkills = const [],
    this.preAssessment,
    this.postAssessment,
  });

  final String topicId;
  final TopicStatus status;

  /// Which sub-skills to teach, in authored order. Stored alongside the full
  /// pre-assessment rather than derived from it on every read: this is what
  /// the learning phase asks for on every screen.
  final List<String> weakSubSkills;

  /// Sub-skills whose practice the learner has finished. Reading a lesson
  /// is not enough — completion means they answered questions about it
  /// (SPEC §7: finishing lessons is not the same as knowing).
  final List<String> completedSubSkills;

  final ScoreSnapshot? preAssessment;
  final ScoreSnapshot? postAssessment;

  /// How much of the plan is behind them.
  int get doneCount =>
      weakSubSkills.where(completedSubSkills.contains).length;

  bool isDone(String subSkillId) => completedSubSkills.contains(subSkillId);
}

/// One assessment, flattened for storage.
class ScoreSnapshot {
  const ScoreSnapshot({
    required this.correct,
    required this.total,
    required this.percent,
    required this.takenAt,
    required this.subSkills,
  });

  final int correct;
  final int total;
  final int percent;
  final DateTime takenAt;
  final List<SubSkillSnapshot> subSkills;
}

class SubSkillSnapshot {
  const SubSkillSnapshot({
    required this.id,
    required this.correct,
    required this.total,
    required this.qualified,
  });

  final String id;
  final int correct;
  final int total;
  final bool qualified;
}

/// What a saved result changes about the plan.
///
/// Only the first check sets the plan. The final check measures whether the
/// lessons worked — treating its result as a new plan silently invalidated
/// the ticks beside the old one, and could re-offer the final check the
/// instant it was finished.
///
/// When the plan *is* rewritten, completions are kept only for sub-skills
/// still in it. Otherwise "3 of 2 done" is reachable, and work on a
/// sub-skill the learner has since passed keeps counting.
///
/// Pure and separate so it can be tested without Firestore.
@visibleForTesting
Map<String, Object?> planUpdate({
  required AssessmentResult result,
  required List<String> storedDone,
}) {
  if (result.phase != AssessmentPhase.pre) return const {};

  final weak = [for (final s in result.weakSubSkills) s.subSkillId];

  return {
    'weakSubSkills': weak,
    'completedSubSkills': [
      for (final id in storedDone)
        if (weak.contains(id)) id,
    ],
  };
}

/// Reads and writes a learner's progress.
abstract interface class ProgressRepository {
  /// Records a scored assessment and moves the topic's status on.
  Future<void> saveAssessment(AssessmentResult result);

  Future<TopicProgress?> topicProgress(String topicId);

  /// Records that a sub-skill's practice is finished, and moves the topic to
  /// at least [TopicStatus.learning].
  Future<void> markSubSkillComplete({
    required String topicId,
    required String subSkillId,
  });

  /// Called on launch, so retention can be measured.
  Future<void> touch();
}

/// Firestore, under `users/{phone}`.
///
/// The document path is the phone number, which is also the Firebase uid —
/// so the security rule is `request.auth.uid == phone` and nothing here has
/// to pass an owner around.
class FirestoreProgressRepository implements ProgressRepository {
  FirestoreProgressRepository(this._firestore, this._session);

  final FirebaseFirestore _firestore;
  final SessionService _session;

  DocumentReference<Map<String, dynamic>>? get _user {
    final phone = _session.currentPhone;
    return phone == null ? null : _firestore.collection('users').doc(phone);
  }

  @override
  Future<void> saveAssessment(AssessmentResult result) async {
    final user = _user;
    // Signed out, or the token exchange failed. Losing a result is bad, but
    // a crash mid-assessment is worse, and the gate makes this unreachable
    // in normal use.
    if (user == null) return;

    final now = DateTime.now();
    final field = switch (result.phase) {
      AssessmentPhase.pre => 'preAssessment',
      AssessmentPhase.post => 'postAssessment',
    };

    await _ensureUser(user);

    final doc = user.collection('topics').doc(result.topicId);

    // Read first so the status can only move forward. A plain get rather
    // than a transaction: get() falls back to the local cache offline and
    // set() queues, so an assessment taken with no signal is still saved.
    // A transaction would need the network and would lose the result.
    final data = (await doc.get()).data();
    final current = TopicStatus.values.firstWhere(
      (s) => s.name == data?['status'],
      orElse: () => TopicStatus.notStarted,
    );

    await doc.set(
        {
          'status': current.furthest(result.phase.reaches).name,
          ...planUpdate(
            result: result,
            storedDone:
                (data?['completedSubSkills'] as List?)?.cast<String>() ??
                    const [],
          ),
          field: {
            'correct': result.correct,
            'total': result.total,
            'percent': result.percent,
            'takenAt': Timestamp.fromDate(now),
            'subSkills': [
              for (final s in result.subSkills)
                {
                  'id': s.subSkillId,
                  'correct': s.correct,
                  'total': s.total,
                  'qualified': s.qualified,
                },
            ],
          },
        },
        // Merge, so a post-assessment never erases the pre-assessment it is
        // being compared against.
        SetOptions(merge: true),
      );
  }

  /// Creates the parent document if it is missing, and stamps the visit.
  ///
  /// A transaction because `createdAt` must be written once and never again:
  /// merging it on every write would reset it, and omitting it from
  /// `mergeFields` would mean it was never written at all.
  Future<void> _ensureUser(DocumentReference<Map<String, dynamic>> user) {
    return _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(user);

      tx.set(
        user,
        {
          'phone': _session.currentPhone,
          'lastSeenAt': FieldValue.serverTimestamp(),
          if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> markSubSkillComplete({
    required String topicId,
    required String subSkillId,
  }) async {
    final user = _user;
    if (user == null) return;

    final doc = user.collection('topics').doc(topicId);

    // A transaction because the new status depends on the stored one, and
    // TopicStatus.furthest must never walk a learner backwards — a second
    // device finishing an older lesson cannot undo a completed topic.
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(doc);
      final stored = snapshot.data()?['status'] as String?;

      final current = TopicStatus.values.firstWhere(
        (s) => s.name == stored,
        orElse: () => TopicStatus.notStarted,
      );

      tx.set(
        doc,
        {
          'status': current.furthest(TopicStatus.learning).name,
          'completedSubSkills': FieldValue.arrayUnion([subSkillId]),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<TopicProgress?> topicProgress(String topicId) async {
    final user = _user;
    if (user == null) return null;

    final snapshot = await user.collection('topics').doc(topicId).get();
    final data = snapshot.data();
    if (data == null) return null;

    return TopicProgress(
      topicId: topicId,
      status: TopicStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TopicStatus.notStarted,
      ),
      weakSubSkills:
          (data['weakSubSkills'] as List?)?.cast<String>() ?? const [],
      completedSubSkills:
          (data['completedSubSkills'] as List?)?.cast<String>() ?? const [],
      preAssessment: _snapshotFrom(data['preAssessment']),
      postAssessment: _snapshotFrom(data['postAssessment']),
    );
  }

  ScoreSnapshot? _snapshotFrom(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;

    return ScoreSnapshot(
      correct: (raw['correct'] as num?)?.toInt() ?? 0,
      total: (raw['total'] as num?)?.toInt() ?? 0,
      percent: (raw['percent'] as num?)?.toInt() ?? 0,
      takenAt: (raw['takenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      subSkills: [
        for (final s in (raw['subSkills'] as List? ?? const []))
          if (s is Map<String, dynamic>)
            SubSkillSnapshot(
              id: s['id'] as String? ?? '',
              correct: (s['correct'] as num?)?.toInt() ?? 0,
              total: (s['total'] as num?)?.toInt() ?? 0,
              qualified: s['qualified'] == true,
            ),
      ],
    );
  }

  @override
  Future<void> touch() async {
    final user = _user;
    if (user == null) return;

    await _ensureUser(user);
  }
}

/// What the learner has done with one topic, or null if they have not
/// started it.
///
/// Read rather than watched: progress changes only when this app writes it,
/// and a live listener would cost a Firestore connection per topic screen
/// for no benefit. Invalidate after a write to refresh.
final topicProgressProvider =
    FutureProvider.family<TopicProgress?, String>((ref, topicId) {
  return ref.watch(progressRepositoryProvider).topicProgress(topicId);
});

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => FirestoreProgressRepository(
    FirebaseFirestore.instance,
    ref.watch(sessionServiceProvider),
  ),
);
