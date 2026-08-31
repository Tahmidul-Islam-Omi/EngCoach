// Flutter's own Feedback (haptics) is unused here and collides with the
// content model's Feedback, which is the authored explanation.
import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/question.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../shared/widgets/answer_option.dart';
import '../../../shared/widgets/bangla_text.dart';
import '../../../shared/widgets/markup_text.dart';
import '../../../shared/widgets/question_progress.dart';
import '../../../shared/widgets/retry_message.dart';
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
  late final PracticeKey _key = (
    topicId: widget.topicId,
    subSkillId: widget.subSkillId,
  );

  @override
  void initState() {
    super.initState();
    // The view model outlives this screen, so a previous visit that ended in
    // "finished" would still be showing its summary. Invalidate rather than
    // calling restart(): mutating a notifier from a life-cycle is forbidden.
    ref.invalidate(practiceViewModelProvider(_key));
  }

  /// The next thing in the plan, so the summary can offer it directly.
  ///
  /// Without this the only way on was "Back to the lesson", then "Done for
  /// now", then scrolling the plan — three taps to reach the obvious step,
  /// the first of them pointing backwards.
  ///
  /// Computed here rather than read from stored progress, because this
  /// lesson's completion is still being written when the summary appears.
  _Next _whatIsNext() {
    final topic = ref.watch(topicProvider(widget.topicId)).value;
    final progress = ref.watch(topicProgressProvider(widget.topicId)).value;
    if (topic == null || progress == null) return const _Next.unknown();

    final plan = topic
        .subSkillsNamed(progress.weakSubSkills)
        .map((s) => s.id)
        .toList();

    // Everything still outstanding, ignoring the one just finished.
    final left = [
      for (final id in plan)
        if (id != widget.subSkillId && !progress.isDone(id)) id,
    ];

    return left.isEmpty ? const _Next.finalCheck() : _Next.lesson(left.first);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceViewModelProvider(_key));
    final model = ref.read(practiceViewModelProvider(_key).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: switch (state.status) {
        PracticeStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PracticeStatus.failed => RetryMessage(
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
          next: _whatIsNext(),
          topicId: widget.topicId,
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
        QuestionProgress(position: state.position, total: state.total),
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
                AnswerOption(
                  key: ValueKey(item.options[i].id),
                  letter: String.fromCharCode(65 + i),
                  text: item.options[i].text,
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
        _Footer(enabled: state.revealed, isLast: state.isLast, onNext: onNext),
      ],
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
            BanglaText(feedback!.bn, color: tone),
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

/// What the plan says to do after this lesson.
class _Next {
  const _Next.lesson(this.subSkillId) : isFinalCheck = false;
  const _Next.finalCheck() : subSkillId = null, isFinalCheck = true;

  /// Progress has not loaded, so offer nothing but the way back.
  const _Next.unknown() : subSkillId = null, isFinalCheck = false;

  final String? subSkillId;
  final bool isFinalCheck;
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.correct,
    required this.total,
    required this.onRetry,
    required this.next,
    required this.topicId,
  });

  final int correct;
  final int total;
  final VoidCallback onRetry;
  final _Next next;
  final String topicId;

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
              color: perfect ? AppColors.successSurface : AppColors.infoSurface,
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
              onPressed: () {
                final router = GoRouter.of(context);
                // Leave the lesson behind as well, so going back from here
                // lands on the plan rather than on what was just read.
                router.pop();

                if (next.isFinalCheck) {
                  router.pushReplacement(Routes.postAssessment(topicId));
                } else if (next.subSkillId != null) {
                  router.pushReplacement(
                    Routes.lesson(topicId, next.subSkillId!),
                  );
                }
              },
              child: Text(
                next.isFinalCheck
                    ? 'Take the final check'
                    : next.subSkillId != null
                    ? 'Next lesson'
                    : 'Back to the lesson',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Practise again')),
        ],
      ),
    );
  }
}
