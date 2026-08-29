import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../data/models/assessment_result.dart';

/// What a finished pre-assessment tells the learner.
///
/// The headline is the sub-skill breakdown, not the percentage: SPEC §6
/// Phase 1 exists to decide what to teach, and "you got 67%" answers a
/// question nobody asked. The score is shown, but smaller.
///
/// Nothing here is persisted yet — that arrives with `ProgressRepository`.
class AssessmentResultView extends StatelessWidget {
  const AssessmentResultView({
    required this.topicId,
    required this.result,
    required this.onRetake,
    super.key,
  });

  final String topicId;
  final AssessmentResult result;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final weak = result.weakSubSkills;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your result'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.sm,
                AppSpacing.pageH,
                AppSpacing.xxxl,
              ),
              children: [
                _Headline(result: result),
                const SizedBox(height: AppSpacing.xl),
                Text('SUB-SKILL BY SUB-SKILL', style: text.labelSmall),
                const SizedBox(height: AppSpacing.md),
                for (final score in result.subSkills) ...[
                  _SubSkillRow(score: score),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  weak.isEmpty
                      ? 'Nothing here needs teaching. Take the check again '
                          'any time to confirm it.'
                      : 'Your lessons will cover the '
                          '${weak.length == 1 ? 'one' : weak.length} '
                          '${weak.length == 1 ? 'sub-skill' : 'sub-skills'} '
                          'marked Focus. The rest you can skip.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          _Footer(onRetake: onRetake),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.result});

  final AssessmentResult result;

  /// Addressed to the learner, and specific about what happens next — the
  /// outcome names a decision, so the wording should too.
  (String, String) get _wording => switch (result.outcome) {
        AssessmentOutcome.fullPass => (
            'You already know this.',
            'Every sub-skill came back clear, so the lessons are optional.',
          ),
        AssessmentOutcome.partial => (
            "Here's what to work on.",
            'Some of this is already solid. The lessons will skip that and '
                'go straight to the gaps.',
          ),
        AssessmentOutcome.insufficient => (
            "We'll start from the beginning.",
            'Nothing came back solid enough to skip yet — which is exactly '
                'what the lessons are for.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (title, detail) = _wording;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title, style: text.headlineSmall),
                ),
                const SizedBox(width: AppSpacing.md),
                // Present, but not the point.
                Text(
                  '${result.correct}/${result.total}',
                  style: text.headlineSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(detail, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SubSkillRow extends StatelessWidget {
  const _SubSkillRow({required this.score});

  final SubSkillScore score;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Colour never carries the meaning on its own — the badge is labelled.
    final tone = score.qualified
        ? AppStatusColors.completed
        : AppStatusColors.learning;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(score.title, style: text.titleLarge),
                const SizedBox(height: 2),
                Text(
                  score.total == 0
                      ? 'Not checked'
                      : '${score.correct} of ${score.total} correct',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              score.qualified ? 'SKIP' : 'FOCUS',
              style: text.labelSmall?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onRetake});

  final VoidCallback onRetake;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Becomes "Start learning" once Phase 2 exists. Until then this
            // goes where it says it goes, rather than to a dead end.
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back to topic'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onRetake,
              child: const Text('Take the check again'),
            ),
          ],
        ),
      ),
    );
  }
}
