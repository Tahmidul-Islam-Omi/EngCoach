/// Spacing, radii and sizing constants.
///
/// Use these instead of raw numbers so density can be tuned in one place.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Standard horizontal page padding.
  static const pageH = 20.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;

  /// Cards.
  static const lg = 14.0;

  /// Emphasised cards, e.g. Today's Review.
  static const xl = 16.0;

  /// Buttons, chips and badges.
  static const pill = 999.0;
}

abstract final class AppSizes {
  /// Minimum touch target on Android.
  ///
  /// Material specifies 48dp. The Figma prototype used 44, which is the iOS
  /// figure — every interactive element here uses 48.
  static const minTapTarget = 48.0;

  /// Height of primary buttons.
  static const buttonHeight = 52.0;

  /// Hairline borders.
  static const borderWidth = 1.0;

  /// Border on a selected option.
  static const selectedBorderWidth = 2.0;

  /// Progress bars and step rails.
  static const barHeight = 6.0;
  static const barHeightThin = 4.0;
}
