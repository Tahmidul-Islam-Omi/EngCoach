import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_ladder.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_label.dart';

/// What the vocabulary check says about the learner (SPEC §6).
///
/// Two answers, in the order they matter: the level the ladder settled on,
/// and the areas the plan will spend time on. The per-area figures are shown
/// because they are the evidence behind the second answer — a learner told
/// "work on collocations" deserves to see why.
class VocabCheckResultView extends StatelessWidget {
  const VocabCheckResultView({
    required this.course,
    required this.profile,
    required this.levelTitle,
    required this.onStart,
    required this.onRetake,
    super.key,
  });

  final VocabCourse course;
  final VocabProfile profile;
  final String? levelTitle;
  final VoidCallback onStart;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final focus = profile.focusSubSkillIds.toSet();

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
                _LevelCard(level: profile.level, title: levelTitle),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.allClear
                              ? 'Nothing here needs work.'
                              : "Here's what to work on.",
                          style: text.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          profile.allClear
                              ? 'Every area came back clear at this level, so '
                                    'the lessons are optional.'
                              : 'The lessons will skip what is already solid '
                                    'and go straight to the areas below.',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Area by area'),
                const SizedBox(height: AppSpacing.md),
                // Only the areas the check actually asked about. A level
                // may author fewer than six, and a row for one never
                // measured would be a verdict on nothing.
                for (final subSkill in course.subSkills)
                  if (profile.scoreFor(subSkill.id) != null) ...[
                    _AreaRow(
                      title: subSkill.title,
                      isFocus: focus.contains(subSkill.id),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          ),
          _Footer(
            hasFocus: !profile.allClear,
            onStart: onStart,
            onRetake: onRetake,
          ),
        ],
      ),
    );
  }
}

/// The headline answer: which rung the ladder settled on.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.title});

  final int level;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
            'YOUR LEVEL',
            style: text.labelSmall?.copyWith(color: AppColors.onPrimaryMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title == null ? 'Level $level' : 'Level $level — $title',
            style: text.headlineLarge?.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your lessons and practice are set at this level.',
            style: text.bodySmall?.copyWith(color: AppColors.onPrimaryBody),
          ),
        ],
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.title, required this.isFocus});

  final String title;
  final bool isFocus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Colour never carries the meaning on its own — the badge is labelled.
    final tone = isFocus ? AppStatusColors.learning : AppStatusColors.completed;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      child: Row(
        children: [
          // Deliberately no score beside the badge. The figures aggregate
          // every level the learner climbed, while the badge is decided at
          // the one they settled on — so two areas could read "2 of 3" with
          // opposite badges, and the learner would have no way to tell why.
          // The real numbers appear on the outcome screen, where before and
          // after are measured the same way.
          Expanded(child: Text(title, style: text.titleLarge)),
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
              isFocus ? 'FOCUS' : 'SKIP',
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
    required this.hasFocus,
    required this.onStart,
    required this.onRetake,
  });

  final bool hasFocus;
  final VoidCallback onStart;
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
            FilledButton(
              onPressed: onStart,
              child: Text(hasFocus ? 'Start learning' : 'Back to vocabulary'),
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
