import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Before against after, which is the product's actual claim (SPEC §4.4).
///
/// Two screens draw it: the post-check result, where it covers one topic,
/// and Progress, where it covers every topic that has been re-checked. They
/// use one widget so the number a learner meets once per topic and the one
/// they can open any time are recognisably the same card.
class ImprovementCard extends StatelessWidget {
  const ImprovementCard({
    required this.before,
    required this.after,
    this.caption,
    super.key,
  });

  final int before;
  final int after;

  /// Replaces the default sentence under the scores. Progress passes its own,
  /// because "the same rules, asked differently" is true of one topic's two
  /// papers and not of an average across several.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gain = after - before;
    final better = gain > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            better ? 'YOU IMPROVED' : 'BEFORE AND AFTER',
            style: text.labelSmall?.copyWith(color: AppColors.onPrimaryMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Score(label: 'Before', percent: before, muted: true),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.onPrimaryMuted,
                ),
              ),
              _Score(label: 'After', percent: after, muted: false),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            caption ??
                switch (gain) {
                  > 0 =>
                    'Up $gain points on the same rules, asked '
                        'differently.',
                  0 =>
                    'The same score on different questions covering the same '
                        'rules.',
                  _ =>
                    'Down ${-gain} points. Worth going back over the '
                        'lessons before moving on.',
                },
            style: text.bodySmall?.copyWith(color: AppColors.onPrimaryBody),
          ),
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({
    required this.label,
    required this.percent,
    required this.muted,
  });

  final String label;
  final int percent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(color: AppColors.onPrimaryMuted),
        ),
        Text(
          '$percent%',
          style: text.headlineLarge?.copyWith(
            color: muted ? AppColors.onPrimaryMuted : AppColors.onPrimary,
          ),
        ),
      ],
    );
  }
}
