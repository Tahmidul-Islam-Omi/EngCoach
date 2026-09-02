import 'dart:convert';
import 'dart:io';

import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/lesson_block.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/features/lesson/view/lesson_block_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Renders blocks at a real phone width, so an overflow fails the test
  /// rather than showing up as stripes on a device.
  Future<void> pumpBlocks(WidgetTester tester, List<LessonBlock> blocks) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final b in blocks) ...[
                LessonBlockView(b),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Everything on screen, markup already resolved.
  List<String> renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text, skipOffstage: false))
      .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
      .toList();

  group('each block type', () {
    testWidgets('a paragraph shows its text without the markers', (
      tester,
    ) async {
      await pumpBlocks(tester, [
        const TextBlock(text: 'With **I** and **you**, the verb stays.'),
      ]);

      expect(renderedText(tester), contains('With I and you, the verb stays.'));
    });

    testWidgets('a pattern shows the rule and its tail', (tester) async {
      await pumpBlocks(tester, [
        const PatternBlock(
          text: 'I / you / we / they + verb',
          highlight: 'no change',
        ),
      ]);

      expect(renderedText(tester), contains('I / you / we / they + verb'));
      expect(renderedText(tester), contains('no change'));
    });

    testWidgets('a table shows every header and cell', (tester) async {
      await pumpBlocks(tester, [
        const TableBlock(
          headers: ['Base form', 'He / she / it'],
          rows: [
            ['I work', 'He works'],
            ['They live', 'She lives'],
          ],
        ),
      ]);

      final text = renderedText(tester);
      for (final cell in [
        'Base form',
        'He / she / it',
        'I work',
        'He works',
        'They live',
        'She lives',
      ]) {
        expect(text, contains(cell));
      }
    });

    testWidgets('an example marks the taught word inside the sentence', (
      tester,
    ) async {
      await pumpBlocks(tester, [
        const ExamplesBlock(
          items: [ExampleItem(text: 'I work in Dhaka.', highlight: 'work')],
        ),
      ]);

      // One span, not the sentence repeated with the word beside it.
      expect(renderedText(tester), contains('I work in Dhaka.'));
    });

    testWidgets('an example survives a highlight that is not in the text', (
      tester,
    ) async {
      // Never true of authored content, but a lesson must not lose its
      // sentence if it ever becomes true.
      await pumpBlocks(tester, [
        const ExamplesBlock(
          items: [ExampleItem(text: 'I work in Dhaka.', highlight: 'missing')],
        ),
      ]);

      expect(renderedText(tester), contains('I work in Dhaka.'));
    });

    testWidgets('a callout shows its label uppercased', (tester) async {
      await pumpBlocks(tester, [
        const CalloutBlock(label: 'Watch out', text: 'The **-s** is for he.'),
      ]);

      expect(renderedText(tester), contains('WATCH OUT'));
      expect(renderedText(tester), contains('The -s is for he.'));
    });

    testWidgets('a bangla block keeps its own label', (tester) async {
      await pumpBlocks(tester, [
        const BanglaBlock(label: 'ব্যাখ্যা', text: '**I** এর সাথে base form.'),
      ]);

      expect(renderedText(tester), contains('ব্যাখ্যা'));
      expect(renderedText(tester), contains('I এর সাথে base form.'));
    });
  });

  group('every authored block', () {
    final files =
        Directory('content/grammar')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final name = file.path.split('/').last.replaceAll('.json', '');

      testWidgets('$name renders on a 360dp screen', (tester) async {
        final topic = Topic.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );

        for (final lesson in topic.lessons) {
          await pumpBlocks(tester, lesson.blocks);

          final text = renderedText(tester).join('\n');
          // Authored markup must never reach a learner as characters.
          expect(
            text.contains('**'),
            isFalse,
            reason: '${lesson.id} showed literal markers',
          );
          expect(
            text.trim(),
            isNotEmpty,
            reason: '${lesson.id} rendered nothing',
          );
        }
      });
    }
  });
}
