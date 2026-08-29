import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/topic.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/async_view.dart';

/// What this learner has to study in this topic, and in what order.
///
/// The whole point of the pre-assessment: the list is the sub-skills they got
/// wrong, not every sub-skill in the topic. Someone who already knows four of
/// six sees two lessons here, which is the promise the landing page makes.
class LearningPathScreen extends ConsumerWidget {
  const LearningPathScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = ref.watch(topicProvider(topicId));
    final progress = ref.watch(topicProgressProvider(topicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Your plan')),
      body: AsyncView(
        value: topic,
        onRetry: () => ref.invalidate(topicProvider(topicId)),
        data: (t) => AsyncView(
          value: progress,
          onRetry: () => ref.invalidate(topicProgressProvider(topicId)),
          data: (p) {
            // Never checked, or checked on a device that could not save.
            if (p == null) {
              return _TakeTheCheckFirst(topicId: topicId);
            }

            final weak = t.subSkillsNamed(p.weakSubSkills);

            if (weak.isEmpty) {
              return const _NothingToTeach();
            }

            return _Plan(topic: t, weak: weak, progress: p);
          },
        ),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.topic,
    required this.weak,
    required this.progress,
  });

  final Topic topic;
  final List<SubSkill> weak;
  final TopicProgress progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final skipped = topic.subSkills.length - weak.length;
    final done = progress.doneCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        0,
        AppSpacing.pageH,
        AppSpacing.xxxl,
      ),
      children: [
        Text(topic.title, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          skipped > 0
              ? 'Your check said ${weak.length} of these need work. '
                  "The other $skipped you can skip."
              : 'Your check said all ${weak.length} need work.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('YOUR LESSONS', style: text.labelSmall),
            Text('$done of ${weak.length} done', style: text.labelSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: weak.isEmpty ? 0 : done / weak.length,
            minHeight: AppSizes.barHeightThin,
            backgroundColor: AppColors.divider,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < weak.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _Step(
            number: i + 1,
            subSkill: weak[i],
            title: topic.lessonFor(weak[i].id).title,
            topicId: topic.id,
            done: progress.isDone(weak[i].id),
          ),
        ],
        if (done == weak.length) ...[
          const SizedBox(height: AppSpacing.xl),
          _FinalCheck(topicId: topic.id),
        ],
      ],
    );
  }
}

/// Offered only once every lesson in the plan is done.
///
/// The post-assessment draws from the other bank — the same rules asked
/// differently — so its score can be set against the first one. Taking it
/// early would measure nothing.
class _FinalCheck extends StatelessWidget {
  const _FinalCheck({required this.topicId});

  final String topicId;

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
            'THAT’S EVERY LESSON',
            style: text.labelSmall?.copyWith(color: AppColors.onPrimaryMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Now see how much changed.',
            style: text.headlineSmall?.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The same rules, asked with different questions, set against '
            'the check you took at the start.',
            style: text.bodySmall?.copyWith(color: AppColors.onPrimaryBody),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.onPrimary,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () =>
                context.push(Routes.postAssessment(topicId)),
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
    required this.subSkill,
    required this.title,
    required this.topicId,
    required this.done,
  });

  final int number;
  final SubSkill subSkill;
  final String title;
  final String topicId;

  /// Its practice is finished. Still tappable — going back over a lesson is
  /// exactly what someone should be able to do.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(Routes.lesson(topicId, subSkill.id)),
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
                    Text(subSkill.title, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(title, style: text.bodySmall),
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
  const _TakeTheCheckFirst({required this.topicId});

  final String topicId;

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
              onPressed: () =>
                  context.push(Routes.preAssessment(topicId)),
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
              'Your check came back clear on every sub-skill in this topic.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
