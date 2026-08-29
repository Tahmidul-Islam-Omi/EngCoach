import 'package:engcoach/shared/widgets/markup_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bold = TextStyle(fontWeight: FontWeight.w700);
  const italic = TextStyle(fontStyle: FontStyle.italic);

  List<InlineSpan> spans(String text) =>
      markupSpans(text, boldStyle: bold, italicStyle: italic);

  List<String> runs(String text) =>
      spans(text).map((s) => (s as TextSpan).text!).toList();

  List<bool> emphasis(String text) => spans(text)
      .map((s) => (s as TextSpan).style?.fontWeight == FontWeight.w700)
      .toList();

  List<bool> slanted(String text) => spans(text)
      .map((s) => (s as TextSpan).style?.fontStyle == FontStyle.italic)
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

  test('marks a wrong form in italics', () {
    // Lessons use single asterisks to show the mistake being corrected.
    const line = 'Adding it — *I works* — is the common slip.';
    expect(runs(line), ['Adding it — ', 'I works', ' — is the common slip.']);
    expect(slanted(line), [false, true, false]);
  });

  test('bold wins over italic, so ** is never read as two markers', () {
    const line = 'The **-s** belongs to *he* only.';
    expect(runs(line), ['The ', '-s', ' belongs to ', 'he', ' only.']);
    expect(emphasis(line), [false, true, false, false, false]);
    expect(slanted(line), [false, false, false, true, false]);
  });

  test('leaves an unclosed marker as written', () {
    expect(runs('**unclosed'), ['**unclosed']);
    expect(runs('5 * 3 = 15'), ['5 * 3 = 15']);
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
