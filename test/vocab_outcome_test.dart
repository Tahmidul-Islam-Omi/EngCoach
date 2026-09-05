import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/features/vocabulary/view/vocab_outcome_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/vocabulary_fixture.dart';

void main() {
  final course = VocabCourse.fromJson(courseJson());

  List<VocabSubSkillScore> scores(Map<String, (int, int)> byId) => [
    for (final id in vocabSubSkillIds)
      if (byId[id] case final s?)
        VocabSubSkillScore(subSkillId: id, correct: s.$1, total: s.$2),
  ];

  Future<void> pumpOutcome(
    WidgetTester tester, {
    required VocabPlan plan,
  }) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: VocabOutcomeView(
          course: course,
          plan: plan,
          levelTitle: 'Developing',
          onContinue: () {},
          onNextLevel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VocabPlan planWith({
    required Map<String, (int, int)> before,
    required Map<String, (int, int)> after,
    List<String> stillWeak = const [],
    int level = 2,
  }) => VocabPlan(
    level: level,
    focusSubSkillIds: stillWeak,
    before: scores(before),
    after: scores(after),
  );

  testWidgets('sets each area before against after', (tester) async {
    await pumpOutcome(
      tester,
      plan: planWith(
        before: {'collocations': (0, 1), 'word_meaning': (1, 1)},
        after: {'collocations': (2, 3), 'word_meaning': (1, 1)},
      ),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(2));
  });

  testWidgets('says how many areas moved, not that progress was strong', (
    tester,
  ) async {
    await pumpOutcome(
      tester,
      plan: planWith(
        before: {'collocations': (0, 1), 'phrasal_verbs': (0, 1)},
        after: {'collocations': (3, 3), 'phrasal_verbs': (0, 3)},
        stillWeak: const ['phrasal_verbs'],
      ),
    );

    expect(find.text('One area improved.'), findsOneWidget);
  });

  testWidgets('does not claim progress when the figures did not move', (
    tester,
  ) async {
    await pumpOutcome(
      tester,
      plan: planWith(
        before: {'collocations': (0, 1)},
        after: {'collocations': (0, 3)},
        stillWeak: const ['collocations'],
      ),
    );

    expect(find.text('Nothing moved yet.'), findsOneWidget);
    expect(find.text('Back to your plan'), findsOneWidget);
    expect(find.text('Check your level again'), findsNothing);
  });

  testWidgets('a cleared level offers the one above it', (tester) async {
    await pumpOutcome(
      tester,
      plan: planWith(
        before: {'collocations': (0, 1)},
        after: {'collocations': (3, 3)},
      ),
    );

    expect(find.text('You have cleared this level.'), findsOneWidget);
    expect(find.text('Check your level again'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('the top level offers no rung above it', (tester) async {
    await pumpOutcome(
      tester,
      plan: planWith(
        level: 4,
        before: {'collocations': (0, 1)},
        after: {'collocations': (3, 3)},
      ),
    );

    expect(find.text('You have cleared this level.'), findsOneWidget);
    expect(find.text('Check your level again'), findsNothing);
    expect(find.text('Back to vocabulary'), findsOneWidget);
  });
}
