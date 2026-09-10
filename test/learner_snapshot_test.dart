import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/learner_snapshot.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/data/repositories/vocab_progress_repository.dart';
import 'package:engcoach/data/repositories/vocabulary_repository.dart';
import 'package:engcoach/features/home/viewmodel/home_view_model.dart';
import 'package:engcoach/features/progress/viewmodel/progress_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/topic_fixture.dart';

/// The join Home and Progress share.
void main() {
  late FakeProgressRepository progress;
  late FakeVocabularyRepository vocabulary;

  ProviderContainer build() {
    progress = FakeProgressRepository();
    vocabulary = FakeVocabularyRepository();
    final container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(buildTopic()),
        ),
        progressRepositoryProvider.overrideWithValue(progress),
        vocabularyRepositoryProvider.overrideWithValue(vocabulary),
        vocabProgressRepositoryProvider.overrideWithValue(
          FakeVocabProgressRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('both screens share one read of the learner', () async {
    final container = build();

    await container.read(homeStateProvider.future);
    await container.read(progressReportProvider.future);

    // One read serves both screens. This holds because Riverpod caches
    // allTopicProgressProvider, not because of the shared snapshot — it was
    // already true when each screen assembled its own join. Pinned anyway:
    // reading the repository directly, or marking anything autoDispose,
    // would silently double every launch's Firestore traffic.
    expect(progress.reads, 1);
  });

  test('the snapshot carries what both builders need', () async {
    final container = build();
    final snapshot = await container.read(learnerSnapshotProvider.future);

    expect(snapshot.topics, isNotEmpty);
    expect(snapshot.course.subSkills, isNotEmpty);
    // No check taken, so no plan and nothing to teach.
    expect(snapshot.plan, isNull);
    expect(snapshot.planChunks, isEmpty);
  });

  test('a level is only parsed when a plan names areas', () async {
    final container = build();
    await container.read(learnerSnapshotProvider.future);

    // Reading a level nobody is studying would cost a file parse for a list
    // no screen draws.
    expect(vocabulary.levelReads, 0);
  });
}
