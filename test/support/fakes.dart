import 'dart:convert';
import 'dart:io';

import 'package:engcoach/data/models/assessment_result.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_level.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';

import 'vocabulary_fixture.dart';

/// Hands back one topic, and counts how often it was asked.
///
/// Pass null to make loading fail, which is how the error paths are tested.
class FakeContentRepository implements ContentRepository {
  FakeContentRepository([this.topic]);

  final Topic? topic;
  int loads = 0;

  @override
  Future<Topic> topicById(String id) async {
    loads++;
    final t = topic;
    if (t == null) throw StateError('no such topic');
    return t;
  }

  @override
  Future<List<Topic>> topicsForSection(String section) async => [?topic];
}

/// Records everything written, and serves whatever progress it was given.
///
/// One fake rather than six near-identical stubs: adding a method to
/// [ProgressRepository] used to mean editing the same class in six files.
class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository([this.progress]);

  /// What [topicProgress] returns. Null means the learner has not started.
  final TopicProgress? progress;

  /// Makes [saveAssessment] throw, for the "a failed write must not disturb
  /// the result on screen" cases.
  bool fail = false;

  int reads = 0;
  int touches = 0;

  final saved = <AssessmentResult>[];
  final completed = <String>[];

  @override
  Future<TopicProgress?> topicProgress(String topicId) async {
    reads++;
    return progress;
  }

  @override
  Future<void> saveAssessment(AssessmentResult result) async {
    if (fail) throw StateError('offline');
    saved.add(result);
  }

  @override
  Future<void> markSubSkillComplete({
    required String topicId,
    required String subSkillId,
  }) async => completed.add(subSkillId);

  @override
  Future<void> touch() async => touches++;
}

/// A real authored topic, for tests that need questions with feedback in
/// two languages — which no fixture would reproduce faithfully.
Topic topicFromFile(String name) => Topic.fromJson(
  jsonDecode(File('content/grammar/$name.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Serves the vocabulary fixture without touching the asset bundle.
///
/// Levels are built on demand from [levelJson], so a test can ask for any rung
/// the ladder climbs to without authoring four files.
class FakeVocabularyRepository implements VocabularyRepository {
  FakeVocabularyRepository({this.course_, this.failLevel, this.bankSize = 3});

  final Map<String, dynamic>? course_;

  /// Makes [level] throw for this rung, for the "content could not be read"
  /// case.
  final int? failLevel;

  final int bankSize;

  int levelReads = 0;

  @override
  Future<VocabCourse> course() async =>
      VocabCourse.fromJson(course_ ?? courseJson());

  @override
  Future<VocabLevel> level(int level) async {
    levelReads++;
    if (level == failLevel) throw StateError('offline');
    return VocabLevel.fromJson(levelJson(level: level, bankSize: bankSize));
  }
}
