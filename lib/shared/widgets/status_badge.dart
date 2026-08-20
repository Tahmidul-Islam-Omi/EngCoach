import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/models/topic_status.dart';

/// Topic status pill (SPEC §7).
///
/// Colour and text always travel together — colour alone never carries the
/// meaning, so it still reads for colour-blind learners and in grayscale.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final TopicStatus status;

  AppColorPair get _colors => switch (status) {
        TopicStatus.notStarted => AppStatusColors.notStarted,
        TopicStatus.tested => AppStatusColors.tested,
        TopicStatus.learning => AppStatusColors.learning,
        TopicStatus.completed => AppStatusColors.completed,
        TopicStatus.mastered => AppStatusColors.mastered,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _colors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: _colors.foreground),
      ),
    );
  }
}
