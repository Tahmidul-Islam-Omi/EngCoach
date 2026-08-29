import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/app/theme/app_typography.dart';
import 'package:engcoach/shared/widgets/bangla_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Text> pumpBangla(
    WidgetTester tester,
    String text, {
    Color? color,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: BanglaText(text, color: color)),
      ),
    );
    return tester.widget<Text>(find.byType(Text));
  }

  testWidgets('sets the Bengali family and its line height', (tester) async {
    // Two screens had copied these by hand, which is how a typographic
    // decision drifts.
    final widget = await pumpBangla(tester, 'সহজ বাংলা ব্যাখ্যা।');

    expect(widget.style?.fontFamily, AppTypography.bengali);
    expect(widget.style?.height, AppTypography.bengaliHeight);
  });

  testWidgets('takes a colour but not a family', (tester) async {
    final widget = await pumpBangla(
      tester,
      'ভুল হয়েছে।',
      color: const Color(0xFF92400E),
    );

    expect(widget.style?.color, const Color(0xFF92400E));
    expect(widget.style?.fontFamily, AppTypography.bengali);
  });

  testWidgets('still renders the authored markup', (tester) async {
    final widget = await pumpBangla(tester, '**I** এর সাথে base form বসে।');

    expect(widget.textSpan?.toPlainText(), 'I এর সাথে base form বসে।');
  });
}
