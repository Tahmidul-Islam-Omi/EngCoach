import 'dart:convert';
import 'dart:io';

import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/features/assessment/view/assessment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';
import 'support/topic_fixture.dart';


void main() {
  /// Four questions over two sub-skills, both qualifying at 2 — short enough
  /// to answer end to end in a test.
  Topic shortTopic() => buildTopic(
        subSkills: 2,
        questionsPerSubSkill: 2,
        qualifyingScore: 2,
      );

  /// The fixture's correct option always reads "Option a", so a test can
  /// answer without knowing where the shuffle put it.
  const right = 'Option a';
  const wrong = 'Option b';

  Future<GoRouter> pumpCheck(WidgetTester tester, {Topic? topic}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('topic overview')),
          routes: [
            GoRoute(
              path: 'check',
              builder: (_, _) =>
                  const AssessmentScreen(topicId: 'test_topic'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider
              .overrideWithValue(FakeContentRepository(topic ?? shortTopic())),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/check');
    await tester.pumpAndSettle();
    return router;
  }

  /// The prompt on screen. It renders through MarkupText, so it is a
  /// `Text.rich` and its plain text has to be read off the span.
  String promptOnScreen(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
      .firstWhere((s) => s.startsWith('Prompt for'));

  Future<void> answerAll(WidgetTester tester, {required bool correct}) async {
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(correct ? right : wrong));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }
  }

  group('the question screen', () {
    testWidgets('opens on the first question with nothing chosen',
        (tester) async {
      await pumpCheck(tester);

      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(find.text('CHOOSE ONE.'), findsOneWidget);
      expect(find.text(right), findsOneWidget);

      final next = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(next.onPressed, isNull, reason: 'nothing chosen yet');
    });

    testWidgets('choosing an option enables moving on', (tester) async {
      await pumpCheck(tester);

      await tester.tap(find.text(right));
      await tester.pump();

      final next = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(next.onPressed, isNotNull);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('moves to the next question with a clean slate',
        (tester) async {
      await pumpCheck(tester);
      final first = promptOnScreen(tester);

      await tester.tap(find.text(right));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Question 2 of 4'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'the new question is unanswered',
      );
      expect(promptOnScreen(tester), isNot(first));
    });

    testWidgets('going back keeps the earlier answer', (tester) async {
      await pumpCheck(tester);
      await tester.tap(find.text(right));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
        reason: 'the answer is still on it',
      );
    });

    testWidgets('there is no way back from the first question',
        (tester) async {
      await pumpCheck(tester);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('the last question offers Finish, not Next', (tester) async {
      await pumpCheck(tester);
      for (var i = 0; i < 3; i++) {
        expect(find.text('Next'), findsOneWidget);
        await tester.tap(find.text(right));
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }

      expect(find.text('Question 4 of 4'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('leaving asks first, and staying keeps the answers',
        (tester) async {
      await pumpCheck(tester);
      await tester.tap(find.text(right));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Leave the check?'), findsOneWidget);

      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();

      expect(find.text('Leave the check?'), findsNothing);
      expect(find.text('Question 2 of 4'), findsOneWidget);
    });

    testWidgets('leaving for real returns to the topic', (tester) async {
      await pumpCheck(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('topic overview'), findsOneWidget);
    });
  });

  group('real content', () {
    // Authored questions are longer than any fixture, carry `**bold**` and
    // `___` blanks, and vary in option length — which is where layout gives
    // way. Walking a whole paper renders every one of them.
    for (final path in Directory('content')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.path)
        .toList()
      ..sort()) {
      final name = path.split('/').last.replaceAll('.json', '');

      testWidgets('$name renders every question and scores', (tester) async {
        final topic = Topic.fromJson(
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
        );
        await pumpCheck(tester, topic: topic);

        for (var i = 1; i <= topic.preAssessmentLength; i++) {
          expect(
            find.text('Question $i of ${topic.preAssessmentLength}'),
            findsOneWidget,
          );
          // Authored markup must never reach the screen as characters.
          expect(find.textContaining('**'), findsNothing);

          // Targeted by key, not by the letter badge: the articles topic
          // has an option whose text is literally "A".
          await tester.tap(
            find.byWidgetPredicate((w) => w.key is ValueKey<String>).first,
          );
          await tester.pump();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
        }

        expect(find.text('Your result'), findsOneWidget);
        // A real topic has more sub-skills than fit on one screen, and a
        // ListView only inflates what is near the viewport — so each row has
        // to be scrolled to before it exists to be found.
        for (final subSkill in topic.subSkills) {
          await tester.scrollUntilVisible(
            find.text(subSkill.title),
            120,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(subSkill.title), findsOneWidget);
        }
      });
    }
  });

  group('the result', () {
    testWidgets('a clean sheet reads as already known', (tester) async {
      await pumpCheck(tester);
      await answerAll(tester, correct: true);

      expect(find.text('Your result'), findsOneWidget);
      expect(find.text('You already know this.'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);
      expect(find.text('SKIP'), findsNWidgets(2));
      expect(find.text('FOCUS'), findsNothing);
    });

    testWidgets('getting everything wrong recommends the whole path',
        (tester) async {
      await pumpCheck(tester);
      await answerAll(tester, correct: false);

      expect(find.text("We'll start from the beginning."), findsOneWidget);
      expect(find.text('0/4'), findsOneWidget);
      expect(find.text('FOCUS'), findsNWidgets(2));
    });

    testWidgets('names every sub-skill with its own score', (tester) async {
      await pumpCheck(tester);
      await answerAll(tester, correct: true);

      expect(find.text('Sub-skill 1'), findsOneWidget);
      expect(find.text('Sub-skill 2'), findsOneWidget);
      expect(find.text('2 of 2 correct'), findsNWidgets(2));
    });

    testWidgets('retaking deals a fresh paper', (tester) async {
      await pumpCheck(tester);
      await answerAll(tester, correct: true);

      await tester.tap(find.text('Take the check again'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'the retake starts unanswered',
      );
    });

    testWidgets('going back to the topic leaves the check behind',
        (tester) async {
      await pumpCheck(tester);
      await answerAll(tester, correct: true);

      await tester.tap(find.text('Back to topic'));
      await tester.pumpAndSettle();

      expect(find.text('topic overview'), findsOneWidget);
    });
  });
}
