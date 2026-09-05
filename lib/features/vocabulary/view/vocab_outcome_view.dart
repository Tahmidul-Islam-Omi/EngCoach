import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../shared/widgets/app_card.dart';

/// What the final check proved (SPEC §16, §17).
///
/// The claim the product makes is improvement, so the improvement is the
/// headline and the per-area figures are the evidence for it. Both halves of
/// each pair come from the same words taught in the same lesson — that
/// equivalence is what makes the arrow mean anything.
class VocabOutcomeView extends StatelessWidget {
  const VocabOutcomeView({
    required this.course,
    required this.plan,
    required this.levelTitle,
    required this.onContinue,
    required this.onNextLevel,
    super.key,
  });

  final VocabCourse course;
  final VocabPlan plan;
  final String? levelTitle;

  /// Back to the plan, which the check has just rewritten.
  final VoidCallback onContinue;

  /// Take the ladder check again, aiming higher.
  final VoidCallback onNextLevel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final pairs = [
      for (final s in course.subSkills)
        if (plan.beforeFor(s.id) case final before?)
          if (plan.afterFor(s.id) case final after?)
            (title: s.title, before: before.percent, after: after.percent),
    ];

    final gained = pairs.where((p) => p.after > p.before).length;
    final cleared = plan.isEmpty;
    final atTop = plan.level >= course.ladder.topLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your progress'),
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
                _Headline(
                  level: plan.level,
                  title: levelTitle,
                  gained: gained,
                  cleared: cleared,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('BEFORE AND AFTER', style: text.labelSmall),
                const SizedBox(height: AppSpacing.md),
                for (final pair in pairs) ...[
                  _Pair(
                    title: pair.title,
                    before: pair.before,
                    after: pair.after,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  cleared
                      ? 'Every area came back clear on new words.'
                      : 'What is still marked Focus is what your plan now '
                            'covers.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          _Footer(
            cleared: cleared,
            atTop: atTop,
            nextLevel: plan.level + 1,
            onContinue: onContinue,
            onNextLevel: onNextLevel,
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.level,
    required this.title,
    required this.gained,
    required this.cleared,
  });

  final int level;
  final String? title;
  final int gained;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Addressed to what actually happened. "Strong progress" printed over a
    // set of unchanged figures would be the app telling the learner something
    // the numbers underneath it contradict.
    final (label, headline, body) = switch ((cleared, gained)) {
      (true, _) => (
        'LEVEL ${title == null ? level : '$level — $title'}',
        'You have cleared this level.',
        'Every area came back clear on words you had not seen in the '
            'lesson. The check can place you higher now.',
      ),
      (false, 0) => (
        'LEVEL ${title == null ? level : '$level — $title'}',
        'Nothing moved yet.',
        'The same areas came back weak on new words. Going back over them '
            'is the fastest way to shift it.',
      ),
      _ => (
        'LEVEL ${title == null ? level : '$level — $title'}',
        gained == 1 ? 'One area improved.' : '$gained areas improved.',
        'Measured on words the lesson taught, in sentences you had not '
            'seen before.',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelSmall?.copyWith(color: AppColors.onPrimaryMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            headline,
            style: text.headlineMedium?.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: text.bodySmall?.copyWith(color: AppColors.onPrimaryBody),
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.title, required this.before, required this.after});

  final String title;
  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final up = after > before;
    final down = after < before;

    // Colour never carries the meaning on its own — the numbers are there,
    // and the icon is labelled by the figures either side of it.
    final tone = up
        ? AppColors.success
        : down
        ? AppColors.warning
        : AppColors.textSecondary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      child: Row(
        children: [
          Expanded(child: Text(title, style: text.titleLarge)),
          const SizedBox(width: AppSpacing.md),
          Text(
            '$before%',
            style: text.titleLarge?.copyWith(color: AppColors.textSecondary),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Icon(
              up
                  ? Icons.arrow_upward_rounded
                  : down
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_forward_rounded,
              size: 16,
              color: tone,
            ),
          ),
          Text('$after%', style: text.titleLarge?.copyWith(color: tone)),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.cleared,
    required this.atTop,
    required this.nextLevel,
    required this.onContinue,
    required this.onNextLevel,
  });

  final bool cleared;
  final bool atTop;

  /// Deliberately not printed on the button. The ladder always starts at
  /// Level 1 and has no way down, so it cannot be sent straight to one rung
  /// up without risking placing a learner above where they belong — the
  /// check has to climb to it and prove it.
  final int nextLevel;

  final VoidCallback onContinue;
  final VoidCallback onNextLevel;

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
            // Cleared and there is a rung above: the obvious next step is to
            // find out whether they belong on it (SPEC §17).
            if (cleared && !atTop)
              FilledButton(
                onPressed: onNextLevel,
                child: const Text('Check your level again'),
              )
            else
              FilledButton(
                onPressed: onContinue,
                child: Text(
                  cleared ? 'Back to vocabulary' : 'Back to your plan',
                ),
              ),
            if (cleared && !atTop) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onContinue, child: const Text('Not now')),
            ],
          ],
        ),
      ),
    );
  }
}
