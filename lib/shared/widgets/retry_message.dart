import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// A dead end with a way out of it.
///
/// For failures a screen has already put into learner-facing words — unlike
/// [AsyncView], which is handed a raw error and has to interpret it.
class RetryMessage extends StatelessWidget {
  const RetryMessage({
    required this.onRetry,
    this.message,
    this.icon = Icons.error_outline_rounded,
    super.key,
  });

  final VoidCallback onRetry;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? 'Something went wrong.',
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
