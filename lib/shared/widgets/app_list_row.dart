import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// A tappable row: icon tile, title, subtitle, chevron.
///
/// Four screens had hand-rolled this — Home, Progress, Profile and Learn —
/// and two of them were identical but for the class name. It lives here so a
/// change to the row lands on all of them at once, and so the next section
/// consumes it rather than copying it a fifth time.
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.large = false,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null for a row that cannot be opened yet. The title mutes and the
  /// chevron is dropped, because a chevron promises somewhere to go.
  final VoidCallback? onTap;

  /// The roomier variant used where the row is the screen's main content
  /// rather than one of a list of details.
  final bool large;

  /// Replaces the chevron. Learn passes "Coming soon" for sections that are
  /// not built; without it an untappable row would end in nothing.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = onTap != null;
    final box = large ? 44.0 : 34.0;

    // Radius, border and zero margin all come from the card theme.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: large
              ? const EdgeInsets.all(AppSpacing.lg)
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md + 2,
                  vertical: AppSpacing.md,
                ),
          child: Row(
            children: [
              Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(
                    large ? AppRadius.md : AppRadius.sm + 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: large ? 22 : 18,
                  color: AppColors.textOnMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: large
                          ? text.titleLarge?.copyWith(
                              color: open
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            )
                          : text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (trailing case final widget?)
                widget
              else if (open)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
