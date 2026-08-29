import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type system for EngCoach.
///
/// **Roboto** is the Android system font, so it costs nothing to use: no
/// bundled asset, no download, no flash of fallback text on a slow
/// connection. That matters on the low-end devices most learners are on.
///
/// **Bengali** is handled by [fontFamilyFallback] rather than a separate
/// style. Fallback resolves per *glyph*, so a mixed sentence —
/// "He / she / it-এর শেষে -s যোগ হয়" — renders correctly from a single
/// [TextStyle], with no string splitting or RichText.
abstract final class AppTypography {
  /// The Latin family. **This is the single swap point** — change this
  /// string (and add the matching asset) to move the app to another face.
  ///
  /// Noto Sans Bengali is used for Latin as well as Bengali: it carries a
  /// full Latin set, the two scripts were designed together so they share
  /// proportions and vertical metrics, and it is already bundled — so this
  /// costs nothing beyond the Bengali we needed anyway.
  static const sans = 'NotoSansBengali';

  /// The Bengali family — currently the same file as [sans].
  static const bengali = 'NotoSansBengali';

  /// Line height for Bengali running text.
  ///
  /// Higher than the Latin body's 1.55: conjuncts and matras extend further
  /// above and below the baseline, and collide at Latin spacing. Applied
  /// through [BanglaText] rather than by each caller.
  static const bengaliHeight = 1.75;

  static const fontFamilyFallback = <String>[bengali];

  /// Aligns digits in columns, so the numbers in a score table line up
  /// without needing a monospace font.
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static const _textTheme = TextTheme(
    // Topic name on the Mastered screen.
    headlineLarge: TextStyle(
      fontSize: 25, fontWeight: FontWeight.w700, height: 1.2,
      letterSpacing: -0.4, color: AppColors.textPrimary,
    ),
    // Home greeting.
    headlineMedium: TextStyle(
      fontSize: 23, fontWeight: FontWeight.w700, height: 1.25,
      letterSpacing: -0.3, color: AppColors.textPrimary,
    ),
    // Screen titles and question prompts.
    headlineSmall: TextStyle(
      fontSize: 19, fontWeight: FontWeight.w700, height: 1.35,
      letterSpacing: -0.2, color: AppColors.textPrimary,
    ),
    // Card titles.
    titleLarge: TextStyle(
      fontSize: 16, fontWeight: FontWeight.w700, height: 1.35,
      color: AppColors.textPrimary,
    ),
    // Primary button text.
    titleMedium: TextStyle(
      fontSize: 15, fontWeight: FontWeight.w700, height: 1.3,
      color: AppColors.textPrimary,
    ),
    // Answer options.
    bodyLarge: TextStyle(
      fontSize: 14.5, fontWeight: FontWeight.w400, height: 1.5,
      color: AppColors.textPrimary,
    ),
    // Explanations and rules.
    bodyMedium: TextStyle(
      fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.55,
      color: AppColors.textPrimary,
    ),
    // Supporting and meta text.
    bodySmall: TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.5,
      color: AppColors.textSecondary,
    ),
    // Secondary/text buttons.
    labelLarge: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, height: 1.3,
      color: AppColors.textSecondary,
    ),
    labelMedium: TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.3,
      color: AppColors.textSecondary,
    ),
    // The letter-spaced uppercase section labels.
    labelSmall: TextStyle(
      fontSize: 10, fontWeight: FontWeight.w500, height: 1.4,
      letterSpacing: 1.1, color: AppColors.textSecondary,
    ),
  );

  /// Applies the font family and Bengali fallback to every slot.
  static TextTheme get textTheme => _textTheme.apply(
        fontFamily: sans,
        fontFamilyFallback: fontFamilyFallback,
      );

  // ------------------------------------------------------------ extra styles
  // Styles with no natural Material slot. Read them from the theme's
  // TextTheme where one fits; use these only for what they describe.

  /// Bangla explanation blocks.
  ///
  /// Bengali carries more height above and below the baseline than Latin, so
  /// it needs more leading and reads optically larger at the same size —
  /// hence the taller [height] and slightly smaller [fontSize] than
  /// [TextTheme.bodyMedium].
  static const banglaBlock = TextStyle(
    fontFamily: bengali,
    fontFamilyFallback: [sans],
    fontSize: 13,
    height: 1.85,
    color: AppColors.textPrimary,
  );

  /// Scores and percentages in evidence tables.
  static const numeric = TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    color: AppColors.textSecondary,
  );

  /// The large figures on result screens.
  static const numericLarge = TextStyle(
    fontFamily: sans,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );
}
