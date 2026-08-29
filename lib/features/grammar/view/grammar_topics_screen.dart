import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/topic.dart';
import '../../../data/models/topic_status.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/status_badge.dart';

/// Grammar topic list.
///
/// Topics are tappable in any order (SPEC §5) — the suggestion below is
/// guidance, not a gate.
class GrammarTopicsScreen extends ConsumerWidget {
  const GrammarTopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(sectionTopicsProvider('grammar'));

    return Scaffold(
      appBar: AppBar(title: const Text('Grammar')),
      body: AsyncView(
        value: topics,
        onRetry: () => ref.invalidate(sectionTopicsProvider('grammar')),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  list.length == 1
                      ? '1 topic · Start with the suggested one.'
                      : '${list.length} topics · Not sure where to begin? '
                            'Start with the suggested one.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final topic = list[i - 1];
            return _TopicCard(
              topic: topic,
              suggested: i == 1,
              onTap: () => context.push(Routes.topic(topic.id)),
            );
          },
        ),
      ),
    );
  }
}

class _TopicCard extends ConsumerWidget {
  const _TopicCard({
    required this.topic,
    required this.suggested,
    required this.onTap,
  });

  final Topic topic;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    // Read per card rather than for the whole list: each is one document,
    // Firestore caches them, and a topic the learner has never opened costs
    // a single miss. Unread progress falls back to Not Started, which is
    // what it means.
    final status =
        ref.watch(topicProgressProvider(topic.id)).value?.status ??
        TopicStatus.notStarted;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: suggested ? AppColors.primary : AppColors.border,
          width: suggested
              ? AppSizes.selectedBorderWidth
              : AppSizes.borderWidth,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  size: 20,
                  color: AppColors.textOnMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Long topic names wrap rather than truncate.
                    Text(topic.title, style: text.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    // The suggestion gives way once there is real progress
                    // to report: telling someone to start a topic they are
                    // halfway through reads as the app not knowing them.
                    if (suggested && status == TopicStatus.notStarted)
                      const _SuggestedPill()
                    else
                      StatusBadge(status),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedPill extends StatelessWidget {
  const _SuggestedPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: 3,
    ),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 12, color: AppColors.onPrimary),
        const SizedBox(width: 4),
        // Flexible and shortened: the old label overflowed a 360dp card
        // by 43px, and "START HERE" is the same phrase the topic
        // overview already uses for its first step.
        Flexible(
          child: Text(
            'START HERE',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.onPrimary),
          ),
        ),
      ],
    ),
  );
}
