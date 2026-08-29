import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/answer_option.dart';
import '../../../shared/widgets/markup_text.dart';
import '../../../shared/widgets/question_progress.dart';
import '../../../shared/widgets/retry_message.dart';
import '../../../data/models/assessment_paper.dart';
import '../model/assessment_state.dart';
import '../viewmodel/assessment_view_model.dart';
import 'assessment_result_view.dart';

/// The pre-assessment: one question at a time, no feedback until the end.
///
/// The result lives in the same route rather than a pushed one, because the
/// score is a *state* of this flow, not a place — pushing it would leave the
/// last question sitting behind it, one back-press away from being re-entered
/// after it had already been scored.
class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({
    required this.topicId,
    this.phase = AssessmentPhase.pre,
    super.key,
  });

  final String topicId;
  final AssessmentPhase phase;

  @override
  ConsumerState<AssessmentScreen> createState() =>
      _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  late final AssessmentKey _key =
      (topicId: widget.topicId, phase: widget.phase);

  @override
  void initState() {
    super.initState();
    // The view model is deliberately not auto-disposing, so a leftover paper
    // from a previous visit would still be there. Clearing on the way in —
    // rather than on the way out — keeps it off the widget teardown path,
    // where a ref is no longer safe to use.
    ref.invalidate(assessmentViewModelProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final provider = assessmentViewModelProvider(_key);
    final state = ref.watch(provider);
    final model = ref.read(provider.notifier);

    return switch (state.status) {
      AssessmentStatus.loading => const _Frame(
          child: Center(child: CircularProgressIndicator()),
        ),
      AssessmentStatus.failed => _Frame(
          child: RetryMessage(message: state.error, onRetry: model.retry),
        ),
      AssessmentStatus.inProgress => _Questions(
          phase: widget.phase,
          state: state,
          onSelect: model.select,
          onNext: model.next,
          onPrevious: model.previous,
        ),
      AssessmentStatus.finished => AssessmentResultView(
          topicId: widget.topicId,
          result: state.result!,
          onRetake: model.retake,
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
        appBar: AppBar(title: const Text('Check')),
        body: child,
      );
}


class _Questions extends StatelessWidget {
  const _Questions({
    required this.phase,
    required this.state,
    required this.onSelect,
    required this.onNext,
    required this.onPrevious,
  });

  final AssessmentPhase phase;
  final AssessmentState state;
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
    final question = state.current!;

    return PopScope(
      // The system back gesture would otherwise discard a half-finished
      // paper silently.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            phase == AssessmentPhase.pre ? 'Quick check' : 'Final check',
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Leave the check',
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
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MarkupText(
                    question.question.prompt,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (var i = 0; i < question.options.length; i++) ...[
                    AnswerOption(
                      // Keyed by option id so Flutter cannot carry a
                      // selection over to the next question's tile in the
                      // same position.
                      key: ValueKey(question.options[i].id),
                      letter: String.fromCharCode(65 + i),
                      text: question.options[i].text,
                      isChosen:
                          state.selectedOptionId == question.options[i].id,
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
      // Outside the tab shell nothing else supplies the bottom inset.
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (canGoBack) ...[
              OutlinedButton(
                // The theme sizes outlined buttons full-bleed
                // (`Size.fromHeight`), which is an infinite width inside a
                // Row. Back sits beside Next, so it states its own width.
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
                // Disabled until something is chosen: a check people can
                // click past measures patience, not English.
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
