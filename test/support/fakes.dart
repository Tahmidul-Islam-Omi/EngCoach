import 'package:engcoach/data/models/assessment_result.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';

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
  }) async =>
      completed.add(subSkillId);

  @override
  Future<void> touch() async => touches++;
}
