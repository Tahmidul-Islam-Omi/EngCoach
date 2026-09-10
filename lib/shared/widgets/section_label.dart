import 'package:flutter/material.dart';

/// The small letter-spaced heading that names a block within a screen —
/// YOUR WEAK AREAS, PART BY PART, HOW SIGNING IN WORKS.
///
/// Three screens had declared their own identical widget for this and a
/// dozen more wrote it inline, which made the letter-spaced uppercase style
/// a convention held by habit rather than by code. Uppercasing here rather
/// than in every caller means the decision is in one place: a caller passes
/// the words, not the styling.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}
