import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/features/assessment/model/assessment_result.dart';
import 'package:engcoach/features/assessment/model/pre_assessment_state.dart';
import 'package:engcoach/features/assessment/viewmodel/pre_assessment_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/topic_fixture.dart';

/// Hands back one topic, or fails on demand.
class _StubContent implements ContentRepository {
  _StubContent(this.topic);

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
  Future<List<Topic>> topicsForSection(String section) async =>
      [?topic];
}

void main() {
  const topicId = 'test_topic';

  late _StubContent content;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [contentRepositoryProvider.overrideWithValue(content)],
    );
    addTearDown(c.dispose);
    return c;
  }

  PreAssessmentViewModel modelIn(ProviderContainer c) =>
      c.read(preAssessmentViewModelProvider(topicId).notifier);

  PreAssessmentState stateIn(ProviderContainer c) =>
      c.read(preAssessmentViewModelProvider(topicId));

  /// Waits for the topic to arrive, so the paper is dealt.
  Future<ProviderContainer> started() async {
    final c = makeContainer();
    c.read(preAssessmentViewModelProvider(topicId));
    await c.read(topicProvider(topicId).future).catchError((_) => buildTopic());
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  /// Answers the question on screen correctly and moves on.
  void answerCorrectly(ProviderContainer c) {
    final model = modelIn(c);
    model.select(stateIn(c).current!.correctOptionId);
    model.next();
  }

  void answerWrongly(ProviderContainer c) {
    final model = modelIn(c);
    final question = stateIn(c).current!;
    model.select(question.options.firstWhere((o) => !o.correct).id);
    model.next();
  }

  setUp(() => content = _StubContent(buildTopic()));

  group('starting', () {
    test('is loading until the topic arrives', () {
      final c = makeContainer();

      expect(stateIn(c).status, PreAssessmentStatus.loading);
      expect(stateIn(c).paper, isNull);
    });

    test('deals a paper once the topic is in', () async {
      final c = await started();
      final state = stateIn(c);

      expect(state.status, PreAssessmentStatus.inProgress);
      expect(state.total, 9);
      expect(state.index, 0);
      expect(state.position, 1);
      expect(state.current, isNotNull);
      expect(state.answers, isEmpty);
    });

    test('fails when the topic cannot be read', () async {
      content = _StubContent(null);
      final c = makeContainer();
      c.read(preAssessmentViewModelProvider(topicId));
      await expectLater(
        c.read(topicProvider(topicId).future),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      expect(stateIn(c).status, PreAssessmentStatus.failed);
      expect(stateIn(c).error, isNotNull);
    });

    test('fails rather than deals an empty paper', () async {
      content = _StubContent(buildTopic(bankSize: 0));
      final c = await started();

      expect(stateIn(c).status, PreAssessmentStatus.failed);
      expect(stateIn(c).error, contains('no assessment'));
    });

    test('retry reloads the topic', () async {
      content = _StubContent(null);
      final c = makeContainer();
      c.read(preAssessmentViewModelProvider(topicId));
      await c.read(topicProvider(topicId).future).catchError((_) => buildTopic());
      await Future<void>.delayed(Duration.zero);
      expect(stateIn(c).status, PreAssessmentStatus.failed);

      final before = content.loads;
      modelIn(c).retry();
      await c.read(topicProvider(topicId).future).catchError((_) => buildTopic());
      await Future<void>.delayed(Duration.zero);

      expect(content.loads, greaterThan(before));
    });
  });

  group('answering', () {
    test('records the choice against the question on screen', () async {
      final c = await started();
      final question = stateIn(c).current!;

      modelIn(c).select(question.options.last.id);

      expect(stateIn(c).selectedOptionId, question.options.last.id);
      expect(stateIn(c).answers[question.id], question.options.last.id);
    });

    test('choosing again replaces the answer', () async {
      final c = await started();
      final question = stateIn(c).current!;

      modelIn(c).select(question.options.first.id);
      modelIn(c).select(question.options.last.id);

      expect(stateIn(c).answers, hasLength(1));
      expect(stateIn(c).selectedOptionId, question.options.last.id);
    });

    test('will not advance without an answer', () async {
      final c = await started();

      expect(stateIn(c).canAdvance, isFalse);
      modelIn(c).next();

      expect(stateIn(c).index, 0);
    });

    test('advances once answered', () async {
      final c = await started();
      final first = stateIn(c).current!;

      answerCorrectly(c);

      expect(stateIn(c).index, 1);
      expect(stateIn(c).current!.id, isNot(first.id));
      expect(stateIn(c).selectedOptionId, isNull, reason: 'a fresh question');
    });

    test('goes back with the answer still on it', () async {
      final c = await started();
      final first = stateIn(c).current!;
      answerCorrectly(c);

      modelIn(c).previous();

      expect(stateIn(c).index, 0);
      expect(stateIn(c).selectedOptionId, first.correctOptionId);
    });

    test('does not go back past the first question', () async {
      final c = await started();

      expect(stateIn(c).canGoBack, isFalse);
      modelIn(c).previous();

      expect(stateIn(c).index, 0);
    });

    test('changing an earlier answer changes the score', () async {
      final c = await started();
      final first = stateIn(c).current!;

      answerWrongly(c);
      modelIn(c).previous();
      modelIn(c).select(first.correctOptionId);

      expect(stateIn(c).answers[first.id], first.correctOptionId);
      expect(stateIn(c).answers, hasLength(1));
    });
  });

  group('finishing', () {
    test('the last question scores the paper instead of advancing', () async {
      final c = await started();
      for (var i = 0; i < 9; i++) {
        expect(stateIn(c).status, PreAssessmentStatus.inProgress);
        answerCorrectly(c);
      }

      final state = stateIn(c);
      expect(state.status, PreAssessmentStatus.finished);
      expect(state.result, isNotNull);
      expect(state.result!.percent, 100);
      expect(state.result!.outcome, AssessmentOutcome.fullPass);
    });

    test('knows when it is on the last question', () async {
      final c = await started();
      for (var i = 0; i < 8; i++) {
        expect(stateIn(c).isLast, isFalse);
        answerCorrectly(c);
      }

      expect(stateIn(c).isLast, isTrue);
    });

    test('scores what was actually chosen', () async {
      final c = await started();
      // The first sub-skill right, the other two wrong.
      for (var i = 0; i < 3; i++) {
        answerCorrectly(c);
      }
      for (var i = 0; i < 6; i++) {
        answerWrongly(c);
      }

      final result = stateIn(c).result!;
      expect(result.correct, 3);
      expect(result.outcome, AssessmentOutcome.partial);
      expect(result.weakSubSkills.map((s) => s.subSkillId), ['s2', 's3']);
    });

    test('ignores answering after it has finished', () async {
      final c = await started();
      for (var i = 0; i < 9; i++) {
        answerCorrectly(c);
      }
      final scored = stateIn(c).result;

      modelIn(c).select('anything');
      modelIn(c).next();
      modelIn(c).previous();

      expect(stateIn(c).result, same(scored));
      expect(stateIn(c).status, PreAssessmentStatus.finished);
    });

    test('a retake starts clean', () async {
      final c = await started();
      for (var i = 0; i < 9; i++) {
        answerCorrectly(c);
      }

      modelIn(c).retake();

      final state = stateIn(c);
      expect(state.status, PreAssessmentStatus.inProgress);
      expect(state.index, 0);
      expect(state.answers, isEmpty);
      expect(state.result, isNull);
      expect(state.total, 9);
    });

    test('a retake does not reload the topic', () async {
      final c = await started();
      final before = content.loads;

      modelIn(c).retake();

      expect(content.loads, before);
    });
  });

  group('progress', () {
    test('reads as one of nine at the start and nine of nine at the end',
        () async {
      final c = await started();
      expect(stateIn(c).position, 1);
      expect(stateIn(c).progress, closeTo(1 / 9, 0.001));

      for (var i = 0; i < 8; i++) {
        answerCorrectly(c);
      }

      expect(stateIn(c).position, 9);
      expect(stateIn(c).progress, 1);
      expect(stateIn(c).answeredCount, 8);
    });
  });
}
