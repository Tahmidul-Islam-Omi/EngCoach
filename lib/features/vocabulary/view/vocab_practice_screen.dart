// Flutter's own Feedback (haptics) is unused here and collides with the
// content model's Feedback, which is the authored explanation.
import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/question.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../../shared/widgets/answer_option.dart';
import '../../../shared/widgets/bangla_text.dart';
import '../../../shared/widgets/markup_text.dart';
import '../../../shared/widgets/question_progress.dart';
import '../../../shared/widgets/retry_message.dart';
import '../model/vocab_practice_state.dart';
import '../viewmodel/vocab_plan_view_model.dart';
import '../viewmodel/vocab_practice_view_model.dart';

/// Practice for one word set.
///
/// The answer is revealed the moment it is chosen, with the authored
/// explanation for whatever was picked — in English and in Bangla. That is the
/// whole difference from the check, which deliberately shows nothing: one
/// measures, this one teaches (SPEC §12).
class VocabPracticeScreen extends ConsumerStatefulWidget {
  const VocabPracticeScreen({required this.chunkId, super.key});

  final String chunkId;

  @override
  ConsumerState<VocabPracticeScreen> createState() =>
      _VocabPracticeScreenState();
}

class _VocabPracticeScreenState extends ConsumerState<VocabPracticeScreen> {
  VocabPracticeKey? _key;

  @override
  Widget build(BuildContext context) {
    final planValue = ref.watch(vocabPlanProvider);

    // On a cold start the plan is still being read from Firestore. Showing
    // "take the check first" to a learner who has a plan waiting would be a
    // lie, so loading gets its own state.
    if (planValue.isLoading && !planValue.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final plan = planValue.value;
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              'Take the check first — practice is built from what it finds.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final key = (level: plan.level, chunkId: widget.chunkId);
    if (_key != key) {
      // The view model outlives this screen, so a previous visit that ended in
      // "finished" would still be showing its summary. Invalidating here —
      // during build, before the first watch — rather than in initState keeps
      // it correct when the level changes under a retaken check.
      ref.invalidate(vocabPracticeViewModelProvider(key));
      _key = key;
    }

    final state = ref.watch(vocabPracticeViewModelProvider(key));
    final model = ref.read(vocabPracticeViewModelProvider(key).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: switch (state.status) {
        VocabPracticeStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        VocabPracticeStatus.failed => RetryMessage(
          message: state.error,
          onRetry: model.retry,
        ),
        VocabPracticeStatus.inProgress => _Question(
          state: state,
          onChoose: model.choose,
          onNext: model.next,
        ),
        VocabPracticeStatus.finished => _Summary(
          correct: state.correctCount,
          total: state.total,
          onRetry: model.restart,
          nextChunkId: _nextChunkId(),
        ),
      },
    );
  }

  /// The next unfinished set in the plan, so the summary can offer it
  /// directly rather than sending the learner back to hunt for it.
  String? _nextChunkId() {
    final plan = ref.watch(vocabPlanProvider).value;
    final level = ref.watch(vocabLevelProvider(plan!.level)).value;
    if (level == null) return null;

    for (final chunk in level.chunksFor(plan.focusSubSkillIds)) {
      if (chunk.id != widget.chunkId && !plan.isDone(chunk.id)) {
        return chunk.id;
      }
    }
    return null;
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.state,
    required this.onChoose,
    required this.onNext,
  });

  final VocabPracticeState state;
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
/// mistake for a reader who did not follow it, which is why both are shown
/// rather than one or the other.
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
          // Nothing to move on to until they have answered and been shown why.
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
    required this.nextChunkId,
  });

  final int correct;
  final int total;
  final VoidCallback onRetry;

  /// The next unfinished set, or null when this was the last one.
  final String? nextChunkId;

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
                ? 'These words have stuck. Move on to the next set.'
                : 'The explanations are the point — a wrong answer you read '
                      'through is still work done.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (nextChunkId case final next?)
            FilledButton(
              // Replace rather than push: going back should return to the
              // plan, not walk every set already practised.
              onPressed: () =>
                  context.pushReplacement(Routes.vocabularyChunk(next)),
              child: const Text('Next word set'),
            )
          else
            FilledButton(
              // `go` rather than `pop`: the plan sits two screens down, under
              // the word cards, and popping once would land the learner back
              // on the last card they just finished.
              onPressed: () => context.go(Routes.vocabularyPath),
              child: const Text('Back to your plan'),
            ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: onRetry, child: const Text('Try these again')),
        ],
      ),
    );
  }
}
