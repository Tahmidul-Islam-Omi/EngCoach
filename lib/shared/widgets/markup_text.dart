import 'package:flutter/material.dart';

/// Splits authored text into plain and bold runs.
///
/// `**` is the only markup authored content is allowed to use
/// (`content/README.md`), and it is what highlights the word a question turns
/// on — "She **have** finished". Rendering it literally would put asterisks
/// in front of learners, so every widget that shows authored text goes
/// through here.
///
/// Anything that isn't a closed `**…**` pair is left exactly as written: an
/// odd asterisk is text, not a broken tag.
List<InlineSpan> markupSpans(String text, {required TextStyle? boldStyle}) {
  final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(TextSpan(text: match[1], style: boldStyle));
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
        ),
      ),
      style: base,
      textAlign: textAlign,
      // Screen readers should hear the sentence, not the emphasis runs.
      semanticsLabel: text.replaceAll('**', ''),
    );
  }
}
