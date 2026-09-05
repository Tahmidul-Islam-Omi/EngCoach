import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/models/vocabulary/vocab_course.dart';
import '../../../data/models/vocabulary/vocab_level.dart';
import '../../../data/models/vocabulary/vocab_plan.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/async_view.dart';
import '../viewmodel/vocab_plan_view_model.dart';

/// What this learner has to study, and in what order.
///
/// The whole point of the check: the list is the areas that came back weak at
/// the level they settled on, not every area in the module. Someone who
/// cleared four of six sees two chunks here.
class VocabPathScreen extends ConsumerWidget {
  const VocabPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(vocabPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your plan')),
      body: AsyncView(
        value: plan,
        onRetry: () => ref.invalidate(vocabPlanProvider),
        data: (p) => p == null
            ? const _TakeTheCheckFirst()
            : p.isEmpty
            ? const _NothingToTeach()
            : _Loaded(plan: p),
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.plan});

  final VocabPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(vocabCourseProvider);
    final level = ref.watch(vocabLevelProvider(plan.level));

    return AsyncView(
      value: course,
      onRetry: () => ref.invalidate(vocabCourseProvider),
      data: (c) => AsyncView(
        value: level,
        onRetry: () => ref.invalidate(vocabLevelProvider(plan.level)),
        data: (l) => _Plan(course: c, level: l, plan: plan),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.course, required this.level, required this.plan});

  final VocabCourse course;
  final VocabLevel level;
  final VocabPlan plan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chunks = level.chunksFor(plan.focusSubSkillIds);
    final done = chunks.where((c) => plan.isDone(c.id)).length;

    // Every focus area should have something to teach — the validator proves
    // it for authored content. If a plan somehow names an area this level
    // cannot teach, the chunk simply drops out rather than the screen
    // crashing on it.
    if (chunks.isEmpty) return const _NothingToTeach();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        0,
        AppSpacing.pageH,
        AppSpacing.xxxl,
      ),
      children: [
        Text(
          'Level ${level.level} — ${level.title}',
          style: text.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Based on your check, these are the areas to work on. '
          'Start at the top.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('YOUR WORD SETS', style: text.labelSmall),
            Text('$done of ${chunks.length} done', style: text.labelSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: done / chunks.length,
            minHeight: AppSizes.barHeightThin,
            backgroundColor: AppColors.divider,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < chunks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _Step(
            number: i + 1,
            chunk: chunks[i],
            areaTitle: course.subSkill(chunks[i].subSkillId).title,
            done: plan.isDone(chunks[i].id),
          ),
        ],
        if (plan.readyForFinalCheck(chunks.map((c) => c.id))) ...[
          const SizedBox(height: AppSpacing.xl),
          const _FinalCheck(),
        ],
      ],
    );
  }
}

/// Offered only once every set in the plan has been practised.
///
/// The final check draws from the post bank — the same words the lesson
/// taught, in sentences the learner has not met — so its score can be set
/// against the first check's. Taking it early would measure nothing.
class _FinalCheck extends StatelessWidget {
  const _FinalCheck();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
            'THAT’S EVERY WORD SET',
            style: text.labelSmall?.copyWith(color: AppColors.onPrimaryMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Now see how much changed.',
            style: text.headlineSmall?.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The same words, in sentences you have not seen, set against the '
            'check you took at the start.',
            style: text.bodySmall?.copyWith(color: AppColors.onPrimaryBody),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.onPrimary,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => context.push(Routes.vocabularyFinalCheck),
            child: const Text('Take the final check'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.chunk,
    required this.areaTitle,
    required this.done,
  });

  final int number;
  final VocabChunk chunk;
  final String areaTitle;

  /// Finished. Still tappable — going back over words is exactly what someone
  /// should be able to do.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(Routes.vocabularyChunk(chunk.id)),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          radius: AppRadius.lg,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.success : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.onPrimary,
                      )
                    : Text(
                        '$number',
                        style: text.labelMedium?.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(areaTitle, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${chunk.title} · ${chunk.words.length} words',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.controlOutline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeTheCheckFirst extends StatelessWidget {
  const _TakeTheCheckFirst();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Take the check first.',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your plan is built from what the check finds, so there is '
              'nothing to show until you have taken it.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => context.push(Routes.vocabularyCheck),
              child: const Text('Start the check'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NothingToTeach extends StatelessWidget {
  const _NothingToTeach();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.successSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 30,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Nothing to study here.',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your check came back clear on every area at this level.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            // Without this the screen is a dead end: nothing to study, and no
            // way on to the level that would have something.
            FilledButton(
              onPressed: () => context.push(Routes.vocabularyCheck),
              child: const Text('Check your level again'),
            ),
          ],
        ),
      ),
    );
  }
}
