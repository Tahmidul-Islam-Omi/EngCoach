import 'package:flutter/material.dart';

/// Splits authored text into plain, bold and italic runs.
///
/// `**bold**` marks the word a question or rule turns on — "She **have**
/// finished". `*italic*` marks a form that is *wrong*, which lessons use to
/// show the mistake being corrected: "*I works*, *they lives*". Rendering
/// either literally would put asterisks in front of learners, so every widget
/// that shows authored text goes through here.
///
/// Bold is matched first, so `**` is never mistaken for two italic markers.
/// Anything that isn't a closed pair is left exactly as written: an odd
/// asterisk is text, not a broken tag.
List<InlineSpan> markupSpans(
  String text, {
  required TextStyle? boldStyle,
  TextStyle? italicStyle,
}) {
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*', dotAll: true);
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }

    final bold = match[1];
    spans.add(
      bold != null
          ? TextSpan(text: bold, style: boldStyle)
          : TextSpan(text: match[2], style: italicStyle),
    );
    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }

  return spans;
}

/// A [Text] that understands the authored `**bold**` markup.
class MarkupText extends StatelessWidget {
  const MarkupText(
    this.text, {
    this.style,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;

    return Text.rich(
      TextSpan(
        children: markupSpans(
          text,
          boldStyle: const TextStyle(fontWeight: FontWeight.w700),
          italicStyle: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
      style: base,
      textAlign: textAlign,
      // Screen readers should hear the sentence, not the emphasis runs.
      semanticsLabel: text.replaceAll('*', ''),
    );
  }
}
