/// The renderable pieces of a lesson (SPEC §6, Phase 2).
///
/// A sealed hierarchy rather than a `type` string, so the widget that renders
/// a lesson must handle every block kind — adding a new one becomes a compile
/// error at the switch, not a blank space on screen.
sealed class LessonBlock {
  const LessonBlock();

  factory LessonBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'text' => TextBlock(text: json['text'] as String),
      'pattern' => PatternBlock(
          text: json['text'] as String,
          highlight: json['highlight'] as String,
        ),
      'table' => TableBlock(
          headers: (json['headers'] as List).cast<String>(),
          rows: (json['rows'] as List)
              .map((r) => (r as List).cast<String>())
              .toList(),
        ),
      'examples' => ExamplesBlock(
          items: (json['items'] as List)
              .map((i) => ExampleItem(
                    text: (i as Map<String, dynamic>)['text'] as String,
                    highlight: i['highlight'] as String,
                  ))
              .toList(),
        ),
      'callout' => CalloutBlock(
          label: json['label'] as String,
          text: json['text'] as String,
        ),
      'bangla' => BanglaBlock(
          label: json['label'] as String,
          text: json['text'] as String,
        ),
      _ => throw FormatException('Unknown lesson block type: $type'),
    };
  }
}

/// A paragraph. May contain `**bold**`.
final class TextBlock extends LessonBlock {
  const TextBlock({required this.text});
  final String text;
}

/// The boxed rule, e.g. "he / she / it + verb" + "+ s".
final class PatternBlock extends LessonBlock {
  const PatternBlock({required this.text, required this.highlight});
  final String text;
  final String highlight;
}

/// Two-column comparison.
final class TableBlock extends LessonBlock {
  const TableBlock({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

final class ExamplesBlock extends LessonBlock {
  const ExamplesBlock({required this.items});
  final List<ExampleItem> items;
}

/// One example sentence with the word being taught marked for highlighting.
final class ExampleItem {
  const ExampleItem({required this.text, required this.highlight});
  final String text;
  final String highlight;
}

/// "Watch out" style note.
final class CalloutBlock extends LessonBlock {
  const CalloutBlock({required this.label, required this.text});
  final String label;
  final String text;
}

/// The Bangla explanation — the reason the product exists (SPEC §4.2).
final class BanglaBlock extends LessonBlock {
  const BanglaBlock({required this.label, required this.text});
  final String label;
  final String text;
}
