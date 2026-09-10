import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../../shared/widgets/note.dart';
import '../../../shared/widgets/section_label.dart';
import '../viewmodel/vocab_plan_view_model.dart';

/// The way into the vocabulary module.
///
/// Says what the check is for before asking anyone to sit it: a diagnostic
/// that opens without explaining itself reads as a test to be passed, which
/// is the opposite of what it is.
///
/// Also the only way back to a plan already in progress. Without that, a
/// learner who closed the app mid-plan would find nothing here but "start the
/// check" — and taking it would throw the plan away.
class VocabularyOverviewScreen extends ConsumerWidget {
  const VocabularyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final plan = ref.watch(vocabPlanProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                0,
                AppSpacing.pageH,
                AppSpacing.xxxl,
              ),
              children: [
                Text('Learn and retain new words', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                if (plan != null) ...[
                  _InProgress(plan: plan),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Text(
                  'The check finds the level you are already at and the areas '
                  'that need the most work. It stops as soon as it knows, so '
                  'it is short.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('What it looks at'),
                const SizedBox(height: AppSpacing.md),
                const _Point(
                  icon: Icons.stairs_outlined,
                  title: 'Your level',
                  body:
                      'Four levels, from everyday words to the ones a '
                      'newspaper assumes you know.',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Point(
                  icon: Icons.tune_rounded,
                  title: 'Where the gaps are',
                  body:
                      'Meaning, usage, opposites, word pairs and word '
                      'building are checked separately, so the lessons skip '
                      'what is already solid.',
                ),
                const SizedBox(height: AppSpacing.xl),
                Note(
                  icon: Icons.info_outline_rounded,
                  child: Text(
                    'Nothing is explained during the check. The answers come '
                    'afterwards, in the lessons.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.lg,
              AppSpacing.pageH,
              AppSpacing.lg,
            ),
            child: SafeArea(
              top: false,
              // Three states, not two. "Has a plan" and "has work left" are
              // different things: a learner who cleared the level had a plan,
              // an empty one, and offering to continue it walked them into a
              // screen with nothing on it and no way forward.
              child: switch (plan) {
                null => FilledButton(
                  onPressed: () => context.push(Routes.vocabularyCheck),
                  child: const Text('Start the check'),
                ),
                // Cleared. The only thing left to do is find out whether the
                // next level fits — and there is no plan to lose, so no
                // warning.
                final p when p.isEmpty => FilledButton(
                  onPressed: () => context.push(Routes.vocabularyCheck),
                  child: Text(_nextStepLabel(ref, p)),
                ),
                _ => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: () => context.push(Routes.vocabularyPath),
                      child: const Text('Continue your plan'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => _confirmRetake(context),
                      child: const Text('Take the check again'),
                    ),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// What a learner with a cleared level is being offered.
///
/// The check opens on the level above, so the button names it. At the top
/// there is no rung above and the check simply runs again.
String _nextStepLabel(WidgetRef ref, VocabPlan plan) {
  final top = ref.watch(vocabCourseProvider).value?.ladder.topLevel;

  return top == null || plan.level >= top
      ? 'Check your level again'
      : 'Continue to Level ${plan.level + 1}';
}

/// Retaking replaces the plan and clears every set finished under it, so it
/// asks first. Losing an afternoon's work to a mis-tap is not a state anyone
/// should be able to reach in one gesture.
Future<void> _confirmRetake(BuildContext context) async {
  final again = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Take the check again?'),
      content: const Text(
        'It will replace your current plan, and the word sets you have '
        'already finished will be cleared.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my plan'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Start again'),
        ),
      ],
    ),
  );

  if (again == true && context.mounted) {
    context.push(Routes.vocabularyCheck);
  }
}

/// Where the learner left off, so the plan is worth returning to.
///
/// The total comes from the level's own chunks, counted exactly as the plan
/// screen counts them. Using the number of focus areas instead would be right
/// only while every area happens to be taught by exactly one word set — and
/// the two screens would then disagree the day one is not.
class _InProgress extends ConsumerWidget {
  const _InProgress({required this.plan});

  final VocabPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final level = ref.watch(vocabLevelProvider(plan.level)).value;

    final sets = level?.chunksFor(plan.focusSubSkillIds);
    final done = sets?.where((c) => plan.isDone(c.id)).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Your plan'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            plan.isEmpty
                ? 'Level ${plan.level} — cleared.'
                : sets == null
                // The level has not loaded. Say where they are without
                // inventing a total.
                ? 'Level ${plan.level} — plan in progress.'
                : 'Level ${plan.level} — $done of ${sets.length} '
                      'word sets done.',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge),
              const SizedBox(height: 2),
              Text(body, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
