import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// The standard surface: white, hairline border, rounded.
///
/// Four screens had hand-rolled this same decoration before it lived here,
/// which meant a change to the card style had to be found in four places.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.radius = AppRadius.xl,
    this.background = AppColors.surface,
    this.border = AppColors.border,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// [AppRadius.xl] for the emphasised cards a screen is built around,
  /// [AppRadius.lg] for rows within a list.
  final double radius;

  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
}
