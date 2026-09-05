import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../../shared/widgets/answer_option.dart';
import '../../../shared/widgets/markup_text.dart';
import '../../../shared/widgets/question_progress.dart';
import '../../../shared/widgets/retry_message.dart';
import '../viewmodel/vocab_final_check_view_model.dart';
import '../viewmodel/vocab_plan_view_model.dart';
import 'vocab_outcome_view.dart';

/// The check taken once the plan is finished.
///
/// One continuous paper: the learner is not told which questions are the base
/// pass over every area and which are the extra ones on what they studied.
/// Saying so would tell them which answers matter.
class VocabFinalCheckScreen extends ConsumerStatefulWidget {
  const VocabFinalCheckScreen({super.key});

  @override
  ConsumerState<VocabFinalCheckScreen> createState() =>
      _VocabFinalCheckScreenState();
}

class _VocabFinalCheckScreenState extends ConsumerState<VocabFinalCheckScreen> {
  @override
  void initState() {
    super.initState();
    // The view model outlives this screen, so a finished run from a previous
    // visit would still be showing its outcome. Clearing on the way in keeps
    // it off the widget teardown path, where a ref is no longer safe to use.
    ref.invalidate(vocabFinalCheckProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocabFinalCheckProvider);
    final model = ref.read(vocabFinalCheckProvider.notifier);

    return switch (state.status) {
      VocabFinalStatus.loading => const _Frame(
        child: Center(child: CircularProgressIndicator()),
      ),
      VocabFinalStatus.failed => _Frame(
        child: RetryMessage(message: state.error, onRetry: model.retry),
      ),
      VocabFinalStatus.inProgress => _Questions(
        state: state,
        onSelect: model.select,
        onNext: model.next,
        onPrevious: model.previous,
      ),
      VocabFinalStatus.finished => _Outcome(state: state),
    };
  }
}

/// Builds the outcome from the check's own result rather than waiting for the
/// stored plan to catch up.
///
/// The write that rewrites the plan is deliberately not awaited, so for one
/// frame the stored plan still holds the *old* focus list and no `after` at
/// all. Reading it there would show a learner who scored full marks an empty
/// comparison under a "nothing moved yet" headline, corrected a frame later.
/// The same transformation is applied here and in the repository, so what is
/// on screen is what gets stored.
class _Outcome extends ConsumerWidget {
  const _Outcome({required this.state});

  final VocabFinalState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(vocabPlanProvider).value;
    final course = ref.watch(vocabCourseProvider).value;
    final result = state.result;
    if (stored == null || course == null || result == null) {
      return const _Frame(child: Center(child: CircularProgressIndicator()));
    }

    final plan = stored.withFinalCheck(
      after: result.subSkills,
      stillWeak: state.stillWeak,
    );
    final level = ref.watch(vocabLevelProvider(plan.level)).value;

    return VocabOutcomeView(
      course: course,
      plan: plan,
      levelTitle: level?.title,
      // A cleared plan has nothing left on it, so the button that says
      // "back to vocabulary" goes to vocabulary rather than to an empty list.
      onContinue: () =>
          context.go(plan.isEmpty ? Routes.vocabulary : Routes.vocabularyPath),
      // Straight back into the ladder: the level itself is the question now,
      // and the check is what answers it.
      onNextLevel: () => context.go(Routes.vocabularyCheck),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Final check')),
    body: child,
  );
}

class _Questions extends StatelessWidget {
  const _Questions({
    required this.state,
    required this.onSelect,
    required this.onNext,
    required this.onPrevious,
  });

  final VocabFinalState state;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the final check?'),
        content: const Text(
          "Your answers won't be saved, and you'll start again from the "
          'first question.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (leave == true && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = state.current!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Final check'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Leave the final check',
            onPressed: () => _confirmExit(context),
          ),
        ),
        body: Column(
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
                    question.question.instruction.toUpperCase(),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MarkupText(
                    question.question.prompt,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (var i = 0; i < question.options.length; i++) ...[
                    AnswerOption(
                      key: ValueKey(question.options[i].id),
                      letter: String.fromCharCode(65 + i),
                      text: question.options[i].text,
                      isChosen:
                          state.selectedOptionId == question.options[i].id,
                      // Read only by the debug answer marker; a check never
                      // reveals anything on its own.
                      isAnswer:
                          question.correctOptionId == question.options[i].id,
                      onTap: () => onSelect(question.options[i].id),
                    ),
                    if (i < question.options.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
            _Footer(
              canGoBack: state.canGoBack,
              canAdvance: state.canAdvance,
              isLast: state.isLast,
              onNext: onNext,
              onPrevious: onPrevious,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.canGoBack,
    required this.canAdvance,
    required this.isLast,
    required this.onNext,
    required this.onPrevious,
  });

  final bool canGoBack;
  final bool canAdvance;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

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
        child: Row(
          children: [
            if (canGoBack) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(
                    AppSizes.secondaryButtonWidth,
                    AppSizes.buttonHeight,
                  ),
                ),
                onPressed: onPrevious,
                child: const Text('Back'),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: FilledButton(
                onPressed: canAdvance ? onNext : null,
                child: Text(isLast ? 'Finish' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
