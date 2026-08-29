import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import 'markup_text.dart';

/// Authored Bangla — the explanation a learner falls back on when the
/// English did not land (SPEC §4.2).
///
/// Exists so the script's line height is decided once. Two screens had
/// copied the same `height: 1.75` and font family by hand, which is exactly
/// how a typographic decision drifts.
class BanglaText extends StatelessWidget {
  const BanglaText(this.text, {this.color, this.style, super.key});

  final String text;

  /// Overrides the colour only — the family and line height are not a
  /// caller's decision.
  final Color? color;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium;

    return MarkupText(
      text,
      style: base?.copyWith(
        fontFamily: AppTypography.bengali,
        height: AppTypography.bengaliHeight,
        color: color ?? base.color,
      ),
    );
  }
}
