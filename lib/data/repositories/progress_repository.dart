import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assessment/model/assessment_paper.dart';
import '../../features/assessment/model/assessment_result.dart';
import '../models/topic_status.dart';
import 'session_repository.dart';

/// What a learner has done with one topic.
class TopicProgress {
  const TopicProgress({
    required this.topicId,
    required this.status,
    this.weakSubSkills = const [],
    this.preAssessment,
    this.postAssessment,
  });

  final String topicId;
  final TopicStatus status;

  /// Which sub-skills to teach, in authored order. Stored alongside the full
  /// pre-assessment rather than derived from it on every read: this is what
  /// the learning phase asks for on every screen.
  final List<String> weakSubSkills;

  final ScoreSnapshot? preAssessment;
  final ScoreSnapshot? postAssessment;
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

/// Reads and writes a learner's progress.
abstract interface class ProgressRepository {
  /// Records a scored assessment and moves the topic's status on.
  Future<void> saveAssessment(AssessmentResult result);

  Future<TopicProgress?> topicProgress(String topicId);

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
  final SessionRepository _session;

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

    await user.collection('topics').doc(result.topicId).set(
        {
          'status': _statusAfter(result).name,
          'weakSubSkills': [
            for (final s in result.weakSubSkills) s.subSkillId,
          ],
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

  /// A pre-assessment leaves the topic `tested`; a post-assessment leaves it
  /// `completed`. Mastery is only reachable through a later review
  /// (SPEC §7), never from an assessment alone.
  TopicStatus _statusAfter(AssessmentResult result) =>
      switch (result.phase) {
        AssessmentPhase.pre => TopicStatus.tested,
        AssessmentPhase.post => TopicStatus.completed,
      };

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
      weakSubSkills: (data['weakSubSkills'] as List?)?.cast<String>() ?? const [],
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

/// Stamps `lastSeenAt` — and creates the user document on the first visit —
/// whenever a session exists.
///
/// A provider rather than a `ref.listen` in a widget: WidgetRef.listen only
/// reports *changes*, so a session that had already resolved by the time the
/// widget registered would never be stamped at all. Watching re-runs on the
/// first value as well as every later one.
final visitStampProvider = Provider<void>((ref) {
  final phone = ref.watch(signedInPhoneProvider).value;
  if (phone == null) return;

  final repository = ref.watch(progressRepositoryProvider);
  // Off the build turn, and never surfaced: a missed timestamp is not worth
  // interrupting anyone for.
  Future<void>.microtask(repository.touch);
});

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => FirestoreProgressRepository(
    FirebaseFirestore.instance,
    ref.watch(sessionRepositoryProvider),
  ),
);
