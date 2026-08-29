// Flutter's own Feedback (haptics) is unused here and collides with the
// content model's Feedback, which is the authored explanation.
import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/models/question.dart';
import '../../../shared/widgets/markup_text.dart';
import '../model/practice_state.dart';
import '../viewmodel/practice_view_model.dart';

/// Practice for one lesson.
///
/// The answer is revealed the moment it is chosen, with the authored
/// explanation for whatever was picked — in English and in Bangla. That is
/// the whole difference from the pre-assessment, which deliberately shows
/// nothing (SPEC §6): one measures, this one teaches.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({
    required this.topicId,
    required this.subSkillId,
    super.key,
  });

  final String topicId;
  final String subSkillId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late final PracticeKey _key =
      (topicId: widget.topicId, subSkillId: widget.subSkillId);

  @override
  void initState() {
    super.initState();
    // The view model outlives this screen, so a previous visit that ended in
    // "finished" would still be showing its summary. Invalidate rather than
    // calling restart(): mutating a notifier from a life-cycle is forbidden.
    ref.invalidate(practiceViewModelProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceViewModelProvider(_key));
    final model = ref.read(practiceViewModelProvider(_key).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: switch (state.status) {
        PracticeStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        PracticeStatus.failed => _Failed(
            message: state.error,
            onRetry: model.retry,
          ),
        PracticeStatus.inProgress => _Question(
            state: state,
            onChoose: model.choose,
            onNext: model.next,
          ),
        PracticeStatus.finished => _Summary(
            correct: state.correctCount,
            total: state.total,
            onRetry: model.restart,
          ),
      },
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.state,
    required this.onChoose,
    required this.onNext,
  });

  final PracticeState state;
  final ValueChanged<String> onChoose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = state.current!;

    return Column(
      children: [
        _Progress(position: state.position, total: state.total),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.lg,
              AppSpacing.pageH,
              AppSpacing.xxxl,
            ),
            children: [
              Text(
                item.question.instruction.toUpperCase(),
                style: text.labelSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              MarkupText(item.question.prompt, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < item.options.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _Option(
                  key: ValueKey(item.options[i].id),
                  letter: String.fromCharCode(65 + i),
                  option: item.options[i],
                  revealed: state.revealed,
                  isChosen: state.chosenOptionId == item.options[i].id,
                  isAnswer: item.correctOptionId == item.options[i].id,
                  onTap: () => onChoose(item.options[i].id),
                ),
              ],
              if (state.revealed) ...[
                const SizedBox(height: AppSpacing.xl),
                _Explanation(
                  correct: state.isCorrect,
                  feedback: state.chosenOption?.feedback,
                ),
              ],
            ],
          ),
        ),
        _Footer(
          enabled: state.revealed,
          isLast: state.isLast,
          onNext: onNext,
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.position, required this.total});

  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: position / total,
              minHeight: AppSizes.barHeight,
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Question $position of $total',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// An answer, before and after it is revealed.
///
/// After revealing, the correct option is always marked — not only the one
/// they chose. Someone who guessed wrong needs to see what was right, and
/// someone who guessed right should see it confirmed in the same place.
class _Option extends StatelessWidget {
  const _Option({
    required this.letter,
    required this.option,
    required this.revealed,
    required this.isChosen,
    required this.isAnswer,
    required this.onTap,
    super.key,
  });

  final String letter;
  final QuestionOption option;
  final bool revealed;
  final bool isChosen;
  final bool isAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (border, fill, mark) = switch ((revealed, isAnswer, isChosen)) {
      (false, _, _) => (AppColors.border, AppColors.surface, null),
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

    final tone = switch (mark) {
      Icons.check_rounded => AppColors.success,
      Icons.close_rounded => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: isChosen,
      child: Opacity(
        opacity: revealed && !isAnswer && !isChosen ? 0.55 : 1,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            // Locked once answered: switching after seeing the explanation
            // would be guessing, not practice.
            onTap: revealed ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: AppSizes.minTapTarget),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: border,
                  width: revealed && (isAnswer || isChosen)
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
                      color: mark == null ? Colors.transparent : tone,
                      border: Border.all(
                        color: mark == null ? AppColors.controlOutline : tone,
                      ),
                    ),
                    child: mark == null
                        ? Text(
                            letter,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Icon(mark, size: 17, color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MarkupText(
                      option.text,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The authored explanation for whatever they picked, in both languages.
///
/// Bangla is not a translation of the English line — it explains the same
/// mistake for a reader who did not follow it (SPEC §4.2), which is why both
/// are shown rather than one or the other.
class _Explanation extends StatelessWidget {
  const _Explanation({required this.correct, required this.feedback});

  final bool correct;
  final Feedback? feedback;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = correct ? AppColors.success : AppColors.warning;
    final fill = correct ? AppColors.successSurface : AppColors.warningSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: tone),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 17,
                color: tone,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                correct ? 'THAT’S RIGHT' : 'NOT QUITE',
                style: text.labelSmall?.copyWith(color: tone),
              ),
            ],
          ),
          if (feedback != null) ...[
            const SizedBox(height: AppSpacing.sm),
            MarkupText(
              feedback!.en,
              style: text.bodyMedium?.copyWith(color: tone),
            ),
            const SizedBox(height: AppSpacing.md),
            MarkupText(
              feedback!.bn,
              style: text.bodyMedium?.copyWith(
                color: tone,
                height: 1.75,
                fontFamily: AppTypography.bengali,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.enabled,
    required this.isLast,
    required this.onNext,
  });

  final bool enabled;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.lg,
        AppSpacing.pageH,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          // Nothing to move on to until they have answered and been shown
          // why.
          onPressed: enabled ? onNext : null,
          child: Text(isLast ? 'Finish' : 'Next question'),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.correct,
    required this.total,
    required this.onRetry,
  });

  final int correct;
  final int total;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final perfect = correct == total;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  perfect ? AppColors.successSurface : AppColors.infoSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              perfect ? Icons.check_rounded : Icons.school_outlined,
              size: 30,
              color: perfect ? AppColors.success : AppColors.info,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '$correct of $total right',
            style: text.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            perfect
                ? 'That rule has stuck. Move on to the next lesson.'
                : 'Worth another go — the explanations change nothing, but '
                    'the order of the options will.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: 280,
            child: FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back to the lesson'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onRetry,
            child: const Text('Practise again'),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: AppColors.textSecondary,
            ),
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
