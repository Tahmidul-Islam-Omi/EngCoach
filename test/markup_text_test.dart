import 'package:engcoach/shared/widgets/markup_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bold = TextStyle(fontWeight: FontWeight.w700);

  List<String> runs(String text) => markupSpans(text, boldStyle: bold)
      .map((s) => (s as TextSpan).text!)
      .toList();

  List<bool> emphasis(String text) => markupSpans(text, boldStyle: bold)
      .map((s) => (s as TextSpan).style?.fontWeight == FontWeight.w700)
      .toList();

  test('plain text stays one run', () {
    expect(runs('Which sentence is correct?'), ['Which sentence is correct?']);
    expect(emphasis('Which sentence is correct?'), [false]);
  });

  test('marks the emphasised word and nothing else', () {
    expect(runs('She **have** finished.'), ['She ', 'have', ' finished.']);
    expect(emphasis('She **have** finished.'), [false, true, false]);
  });

  test('handles emphasis at either end', () {
    expect(runs('**Where** had they gone?'), ['Where', ' had they gone?']);
    expect(runs('the pair is **interested in**'), [
      'the pair is ',
      'interested in',
    ]);
  });

  test('handles more than one emphasis in a sentence', () {
    expect(
      emphasis('Use **a** before a consonant and **an** before a vowel.'),
      [false, true, false, true, false],
    );
  });

  test('leaves an unclosed marker as written', () {
    expect(runs('2 ** 3 is not markup'), ['2 ** 3 is not markup']);
    expect(runs('**unclosed'), ['**unclosed']);
  });

  test('leaves a gap-fill blank alone', () {
    expect(runs('I saw ___ cat in the garden.'), [
      'I saw ___ cat in the garden.',
    ]);
  });

  testWidgets('renders without showing the markers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkupText('She **have** finished.')),
      ),
    );

    final widget = tester.widget<Text>(find.byType(Text));
    expect(widget.textSpan!.toPlainText(), 'She have finished.');
  });
}
