import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/shared/widgets/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, String text) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SectionLabel(text)),
    ),
  );

  testWidgets('the caller passes words, the widget does the shouting', (
    tester,
  ) async {
    await pump(tester, 'Your weak areas');
    expect(find.text('YOUR WEAK AREAS'), findsOneWidget);
  });

  testWidgets('an already-uppercase caller is unharmed', (tester) async {
    // Fifteen call sites were converted from literals that were already
    // uppercase; uppercasing twice must not change them.
    await pump(tester, 'PART BY PART');
    expect(find.text('PART BY PART'), findsOneWidget);
  });

  testWidgets('it takes the letter-spaced style from the theme', (
    tester,
  ) async {
    await pump(tester, 'So far');
    // The properties, not the whole TextStyle: the tree merges the platform's
    // own text theme in, so object equality fails on a style that is correct.
    final style = tester.widget<Text>(find.text('SO FAR')).style!;
    final wanted = AppTheme.light.textTheme.labelSmall!;
    expect(style.letterSpacing, wanted.letterSpacing);
    expect(style.fontSize, wanted.fontSize);
    expect(style.color, wanted.color);
  });
}
