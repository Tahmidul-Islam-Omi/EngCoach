import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/assessment_paper.dart';
import '../../../data/models/assessment_result.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../shared/widgets/app_card.dart';

/// What a finished check tells the learner, in either phase.
///
/// The headline is the sub-skill breakdown, not the percentage: SPEC §6
/// Phase 1 exists to decide what to teach, and "you got 67%" answers a
/// question nobody asked. The score is shown, but smaller.
///
/// The two phases share the layout and almost nothing else in the wording.
/// A pre-assessment is a plan being made; a post-assessment is a plan being
/// judged, and telling someone the lessons "will skip that" after they have
/// already sat through them reads as if the app was not paying attention.
class AssessmentResultView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final weak = result.weakSubSkills;

    // The pre-assessment score, for the comparison that is the whole point
    // of taking the second one. Read from what was stored, not from this
    // paper — the two are different questions by design.
    final before = result.phase == AssessmentPhase.post
        ? ref.watch(topicProgressProvider(topicId)).value?.preAssessment
        : null;

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
                if (before != null) ...[
                  _Improvement(before: before.percent, after: result.percent),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // The improvement card is the score story when it is
                // there; repeating the raw count underneath just splits
                // the learner's attention between two of the same number.
                _Headline(result: result, showScore: before == null),
                const SizedBox(height: AppSpacing.xl),
                Text('SUB-SKILL BY SUB-SKILL', style: text.labelSmall),
                const SizedBox(height: AppSpacing.md),
                for (final score in result.subSkills) ...[
                  _SubSkillRow(score: score),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(switch ((result.phase, weak.isEmpty)) {
                  (AssessmentPhase.pre, true) =>
                    'Nothing here needs teaching. Take the check again '
                        'any time to confirm it.',
                  (AssessmentPhase.pre, false) =>
                    'Your lessons will cover everything marked Focus.',
                  (AssessmentPhase.post, true) =>
                    'Nothing is marked Focus any more. This topic is '
                        'complete.',
                  (AssessmentPhase.post, false) =>
                    'Your plan is rebuilt around what is still marked '
                        'Focus.',
                }, style: text.bodySmall),
              ],
            ),
          ),
          _Footer(
            topicId: topicId,
            phase: result.phase,
            firstWeakSubSkill: weak.firstOrNull?.subSkillId,
            onRetake: onRetake,
          ),
        ],
      ),
    );
  }
}

/// Pre against post, which is the product's actual claim (SPEC §6).
///
/// Shown above everything else on a post-assessment: the sub-skill
/// breakdown matters for deciding what to do next, but this is what the
/// learner came back to see.
class _Improvement extends StatelessWidget {
  const _Improvement({required this.before, required this.after});

  final int before;
  final int after;

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
          Text(switch (gain) {
            > 0 => 'Up $gain points on the same rules, asked differently.',
            0 =>
              'The same score on different questions covering the same '
                  'rules.',
            _ =>
              'Down ${-gain} points. Worth going back over the lessons '
                  'before moving on.',
          }, style: text.bodySmall?.copyWith(color: AppColors.onPrimaryBody)),
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

class _Headline extends StatelessWidget {
  const _Headline({required this.result, required this.showScore});

  final AssessmentResult result;

  /// False once the before/after card has already given the number.
  final bool showScore;

  /// Addressed to the learner, and specific about what happens next — the
  /// outcome names a decision, so the wording should too.
  ///
  /// The post-assessment wording talks about lessons already taken. Its
  /// job is to say whether the work held, not to introduce a plan.
  (String, String) get _wording => switch ((result.phase, result.outcome)) {
    (AssessmentPhase.pre, AssessmentOutcome.fullPass) => (
      'You already know this.',
      'Every sub-skill came back clear, so the lessons are optional.',
    ),
    (AssessmentPhase.pre, AssessmentOutcome.partial) => (
      "Here's what to work on.",
      'Some of this is already solid. The lessons will skip that and '
          'go straight to the gaps.',
    ),
    (AssessmentPhase.pre, AssessmentOutcome.insufficient) => (
      "We'll start from the beginning.",
      'Nothing came back solid enough to skip yet — which is exactly '
          'what the lessons are for.',
    ),
    (AssessmentPhase.post, AssessmentOutcome.fullPass) => (
      'It all held up.',
      'Every sub-skill came back clear on new questions. Nothing here '
          'is left to work on.',
    ),
    (AssessmentPhase.post, AssessmentOutcome.partial) => (
      'Most of it held up.',
      'What is still marked Focus did not come back clear on the new '
          'questions — that is what to go over again.',
    ),
    (AssessmentPhase.post, AssessmentOutcome.insufficient) => (
      'This one needs another pass.',
      'The rules did not come back clear on new questions. Going back '
          'through the lessons is the fastest way to fix that.',
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
                Expanded(child: Text(title, style: text.headlineSmall)),
                if (showScore) ...[
                  const SizedBox(width: AppSpacing.md),
                  // Present, but not the point.
                  Text(
                    '${result.correct}/${result.total}',
                    style: text.headlineSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
  const _Footer({
    required this.topicId,
    required this.phase,
    required this.firstWeakSubSkill,
    required this.onRetake,
  });

  final String topicId;
  final AssessmentPhase phase;

  /// Null when every sub-skill qualified — there is nothing to teach.
  final String? firstWeakSubSkill;

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
            // The plan rather than the first lesson: seeing "2 of 6 need
            // work" is the payoff of having taken the check, and it is what
            // makes the skipping believable.
            if (firstWeakSubSkill != null)
              FilledButton(
                onPressed: () => context.push(Routes.learningPath(topicId)),
                child: Text(switch (phase) {
                  AssessmentPhase.pre => 'Start learning',
                  AssessmentPhase.post => 'Back to the lessons',
                }),
              )
            else
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
