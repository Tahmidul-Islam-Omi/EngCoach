import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/answer_option.dart';
import '../../../shared/widgets/markup_text.dart';
import '../../../shared/widgets/question_progress.dart';
import '../../../shared/widgets/retry_message.dart';
import '../model/vocab_check_state.dart';
import '../viewmodel/vocab_check_view_model.dart';
import 'vocab_check_result_view.dart';

/// The vocabulary check: a ladder, not a paper.
///
/// The learner sees one continuous check. Underneath, it may be four papers
/// and a probe — but a screen that announced "now dealing level 3" would be
/// describing the machinery rather than the questions.
///
/// The result lives in this route rather than a pushed one, for the same
/// reason as the grammar assessment: the profile is a *state* of this flow,
/// not a place, and pushing it would leave the last question one back-press
/// away from being re-entered after it had been scored.
class VocabCheckScreen extends ConsumerStatefulWidget {
  const VocabCheckScreen({super.key});

  @override
  ConsumerState<VocabCheckScreen> createState() => _VocabCheckScreenState();
}

class _VocabCheckScreenState extends ConsumerState<VocabCheckScreen> {
  @override
  void initState() {
    super.initState();
    // The view model is deliberately not auto-disposing, so a finished run
    // from a previous visit would still be sitting there. Clearing on the way
    // in — rather than on the way out — keeps it off the widget teardown
    // path, where a ref is no longer safe to use.
    ref.invalidate(vocabCheckViewModelProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocabCheckViewModelProvider);
    final model = ref.read(vocabCheckViewModelProvider.notifier);

    return switch (state.status) {
      VocabCheckStatus.loading => const _Frame(
        child: Center(child: CircularProgressIndicator()),
      ),
      VocabCheckStatus.failed => _Frame(
        child: RetryMessage(message: state.error, onRetry: model.retry),
      ),
      VocabCheckStatus.borderline => _Borderline(
        onContinue: model.continueToProbe,
      ),
      VocabCheckStatus.inProgress => _Questions(
        state: state,
        onSelect: model.select,
        onNext: model.next,
        onPrevious: model.previous,
      ),
      VocabCheckStatus.finished => VocabCheckResultView(
        course: state.course!,
        profile: state.profile!,
        levelTitle: state.levelTitle,
        onStart: () => state.profile!.allClear
            ? context.pop()
            : context.push(Routes.vocabularyPath),
        onRetake: model.restart,
      ),
    };
  }
}

/// Chrome shared by the states that have nothing to ask yet.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vocabulary check')),
    body: child,
  );
}

/// Shown when a level comes back unclear, before the extra questions.
///
/// The learner is told the check is buying more evidence, and why. Handing
/// someone two more questions with no explanation reads as a malfunction —
/// and naming the areas being re-checked would steer the answers, which is
/// exactly what the probe must not do.
class _Borderline extends StatelessWidget {
  const _Borderline({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary check'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ALMOST THERE', style: text.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            Text('You were close.', style: text.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'A couple more questions will settle which level is the right '
              'place to start. They pick up where you were least certain.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(onPressed: onContinue, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({
    required this.state,
    required this.onSelect,
    required this.onNext,
    required this.onPrevious,
  });

  final VocabCheckState state;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the check?'),
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
      // The system back gesture would otherwise discard a half-finished run.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vocabulary check'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Leave the check',
            onPressed: () => _confirmExit(context),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  // The level is worth showing — climbing is the one piece of
                  // progress a learner can feel mid-check. The subskill is
                  // not: naming it would steer the answer.
                  'LEVEL ${state.level}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
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
                      // Keyed by option id so Flutter cannot carry a selection
                      // over to the next question's tile in the same position.
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
    required this.onNext,
    required this.onPrevious,
  });

  final bool canGoBack;
  final bool canAdvance;
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
                // The theme sizes outlined buttons full-bleed, which is an
                // infinite width inside a Row. Back sits beside Next, so it
                // states its own width.
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
                // "Finish" would be a lie on a level the ladder is about to
                // climb past, so the last question of a paper says Next like
                // the others.
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
