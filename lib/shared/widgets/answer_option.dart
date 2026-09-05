import 'package:flutter/material.dart';

import '../../app/debug_flags.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'markup_text.dart';

/// One multiple-choice answer, in either of the two ways this app asks.
///
/// An assessment only ever shows a **selection** — it deliberately reveals
/// nothing until the end (SPEC §6). Practice reveals the moment something is
/// chosen. That is the only difference, so [revealed] switches between them
/// rather than there being two widgets, which is what there used to be.
class AnswerOption extends StatelessWidget {
  const AnswerOption({
    required this.letter,
    required this.text,
    required this.onTap,
    this.revealed = false,
    this.isChosen = false,
    this.isAnswer = false,
    super.key,
  });

  /// A, B, C — a letter rather than a radio dot, which never reads as
  /// "already answered" the way a filled circle can.
  final String letter;

  final String text;
  final VoidCallback onTap;

  /// The answer is out. Locks the tile and colours it by outcome.
  final bool revealed;

  final bool isChosen;
  final bool isAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (border, fill, mark) = switch ((revealed, isAnswer, isChosen)) {
      // Chosen but not yet revealed: an assessment selection.
      (false, _, true) => (AppColors.info, AppColors.infoSurface, null),
      (false, _, false) => (AppColors.border, AppColors.surface, null),
      (true, true, _) => (
        AppColors.success,
        AppColors.successSurface,
        Icons.check_rounded,
      ),
      (true, false, true) => (
        AppColors.danger,
        AppColors.dangerSurface,
        Icons.close_rounded,
      ),
      // Untouched and not the answer: fades back so the eye goes to the two
      // that matter.
      (true, false, false) => (AppColors.border, AppColors.surface, null),
    };

    final tone = switch ((revealed, isAnswer, isChosen)) {
      (false, _, true) => AppColors.info,
      (true, true, _) => AppColors.success,
      (true, false, true) => AppColors.danger,
      _ => AppColors.controlOutline,
    };

    final emphasised = isChosen || (revealed && isAnswer);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: isChosen,
      child: Opacity(
        opacity: revealed && !isAnswer && !isChosen ? 0.55 : 1,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            // Locked once the answer is out: switching after reading the
            // explanation would be guessing, not practice.
            onTap: revealed ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: border,
                  width: emphasised
                      ? AppSizes.selectedBorderWidth
                      : AppSizes.borderWidth,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: emphasised ? tone : Colors.transparent,
                      border: Border.all(
                        color: emphasised ? tone : AppColors.controlOutline,
                      ),
                    ),
                    child: mark == null
                        ? Text(
                            letter,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: emphasised
                                  ? AppColors.onPrimary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Icon(mark, size: 17, color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MarkupText(text, style: theme.textTheme.bodyLarge),
                  ),
                  // Debug only. A bare dot rather than a label, so it cannot
                  // be mistaken for part of the design and cannot collide
                  // with anything a test looks for.
                  if (DebugFlags.revealAnswers && isAnswer && !revealed) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
