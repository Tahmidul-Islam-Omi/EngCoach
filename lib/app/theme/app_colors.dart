import 'package:flutter/material.dart';

/// The single source of truth for colour in EngCoach.
///
/// Every pairing the app actually uses has been checked against WCAG AA:
/// 4.5:1 for body text, 3:1 for UI components and graphical objects.
/// Nothing outside this file should hardcode a hex value.
///
/// Dark mode is not defined yet — no dark screens have been designed. When
/// it arrives, add a second palette here and switch on it in [AppTheme];
/// no call site should need to change.
abstract final class AppColors {
  // ---------------------------------------------------------------- surfaces
  /// Page background behind cards.
  static const background = Color(0xFFEEF1F8);

  /// Cards, sheets, app bar.
  static const surface = Color(0xFFFFFFFF);

  /// Hairline around cards and inputs.
  static const border = Color(0xFFD8DFEA);

  /// Rules inside cards, and the track behind progress bars.
  static const divider = Color(0xFFE2E8F0);

  // ----------------------------------------------------------------- primary
  /// Buttons, filled bars, the Today's Review card.
  static const primary = Color(0xFF16243A);
  static const onPrimary = Color(0xFFFFFFFF);

  /// Labels on top of [primary]. 6.2:1.
  static const onPrimaryMuted = Color(0xFF93A4C0);

  /// Body text on top of [primary]. 10.2:1.
  static const onPrimaryBody = Color(0xFFC7D2E4);

  // -------------------------------------------------------------------- text
  /// Headings and body. 13.8:1 on [background].
  static const textPrimary = Color(0xFF16243A);

  /// Supporting text. 5.2:1 on [background], 5.9:1 on [surface].
  static const textSecondary = Color(0xFF55657F);

  /// Text on [divider]-filled chips and badges. 6.1:1.
  static const textOnMuted = Color(0xFF47566B);

  // ---------------------------------------------------------------- controls
  /// Unselected radio and checkbox outlines. 3.5:1 on [surface] — the
  /// lighter greys that read fine in Figma fail the 3:1 floor for controls.
  static const controlOutline = Color(0xFF7D8BA3);

  /// Not-yet-reached step dots. 3.1:1 on [divider].
  static const controlInactive = Color(0xFF76849C);

  // ---------------------------------------------------------------- semantic
  static const success = Color(0xFF166534);
  static const successSurface = Color(0xFFDCFCE7);

  static const warning = Color(0xFF92400E);
  static const warningSurface = Color(0xFFFEF3C7);

  static const info = Color(0xFF1D4ED8);
  static const infoSurface = Color(0xFFDBEAFE);

  static const danger = Color(0xFFB42318);
  static const dangerSurface = Color(0xFFFEE4E2);
}

/// A foreground/background pair used together, e.g. a status badge.
@immutable
class AppColorPair {
  const AppColorPair({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

/// Colours for the five topic states in SPEC §7:
/// Not Started → Tested → Learning → Completed → Mastered.
///
/// [mastered] is deliberately the only solid fill — it is the state the whole
/// product works toward, so it should outrank the others at a glance. Every
/// badge pairs colour with a text label; colour alone never carries meaning.
abstract final class AppStatusColors {
  static const notStarted = AppColorPair(
    foreground: AppColors.textOnMuted,
    background: AppColors.divider,
  );
  static const tested = AppColorPair(
    foreground: AppColors.info,
    background: AppColors.infoSurface,
  );
  static const learning = AppColorPair(
    foreground: AppColors.warning,
    background: AppColors.warningSurface,
  );
  static const completed = AppColorPair(
    foreground: AppColors.success,
    background: AppColors.successSurface,
  );
  static const mastered = AppColorPair(
    foreground: AppColors.onPrimary,
    background: AppColors.success,
  );
}
