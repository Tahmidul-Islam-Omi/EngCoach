import 'dart:convert';
import 'dart:io';

import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/vocabulary/vocab_course.dart';
import 'package:engcoach/data/models/vocabulary/vocab_level.dart';
import 'package:engcoach/data/models/vocabulary/vocab_plan.dart';
import 'package:engcoach/data/models/vocabulary/vocab_result.dart';
import 'package:engcoach/features/vocabulary/view/vocab_outcome_view.dart';
import 'package:engcoach/features/vocabulary/view/word_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixture's areas are called "Area 1". The real ones are called
/// "Synonyms and antonyms", and a row that fits the first can still overflow
/// on the second — which is only ever seen on a device.
void main() {
  VocabCourse readCourse() => VocabCourse.fromJson(
    jsonDecode(File('content/vocabulary/course.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  VocabLevel readLevel(int n) => VocabLevel.fromJson(
    jsonDecode(File('content/vocabulary/level_$n.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
    await tester.pumpAndSettle();
  }

  testWidgets('the outcome rows hold the real area names at 360dp', (
    tester,
  ) async {
    final course = readCourse();

    // The widest case: every area named, and three-digit percentages both
    // sides of the arrow.
    final scores = [
      for (final s in course.subSkills)
        VocabSubSkillScore(subSkillId: s.id, correct: 3, total: 3),
    ];

    await pump(
      tester,
      VocabOutcomeView(
        course: course,
        plan: VocabPlan(
          level: 4,
          focusSubSkillIds: const [],
          before: scores,
          after: scores,
        ),
        levelTitle: 'Advanced',
        onContinue: () {},
        onNextLevel: () {},
      ),
    );

    for (final s in course.subSkills) {
      await tester.scrollUntilVisible(
        find.text(s.title),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(s.title), findsOneWidget);
    }
  });

  group('every authored word card fits', () {
    for (final level in [1, 2, 3, 4]) {
      testWidgets('level $level', (tester) async {
        for (final chunk in readLevel(level).chunks) {
          for (final word in chunk.words) {
            await pump(
              tester,
              Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [WordCardView(word)],
                ),
              ),
            );
            expect(
              find.text(word.word),
              findsOneWidget,
              reason: '${word.word} did not render',
            );
          }
        }
      });
    }
  });
}
