import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// An aside: an icon and a sentence, boxed.
///
/// Defaults are the quiet grey version. Pass the warning trio together for
/// something that must be read — the charge disclosure, for instance.
class Note extends StatelessWidget {
  const Note({
    required this.icon,
    required this.child,
    this.tone = AppColors.textSecondary,
    this.background = AppColors.surface,
    this.border = AppColors.border,
    super.key,
  });

  final IconData icon;
  final Widget child;
  final Color tone;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg - 2,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 17, color: tone),
            ),
            const SizedBox(width: AppSpacing.sm + 1),
            Expanded(child: child),
          ],
        ),
      );
}
