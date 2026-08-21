import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/topic.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/async_view.dart';

/// Topic overview — what this topic is, and what the learner is about to do.
///
/// Sets expectations before the first check, which SPEC §6 leans on: the
/// diagnostic only works if people answer honestly instead of anxiously.
class TopicOverviewScreen extends ConsumerWidget {
  const TopicOverviewScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = ref.watch(topicProvider(topicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Topic')),
      body: AsyncView(
        value: topic,
        onRetry: () => ref.invalidate(topicProvider(topicId)),
        data: (t) => _Body(topic: t),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.topic});

  final Topic topic;

  /// ~20 seconds per multiple-choice question, rounded to the nearest minute.
  int get _minutes => (topic.preAssessmentLength * 20 / 60).ceil();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            // Extra bottom room so the last step clears the footer rather
            // than reading as clipped.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH, 0, AppSpacing.pageH, AppSpacing.xxxl,
            ),
            children: [
              _SectionChip(topic.section.toUpperCase()),
              const SizedBox(height: AppSpacing.md),
              Text(topic.title, style: text.headlineLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(topic.summary, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHY THIS TOPIC?', style: text.labelSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(topic.whyThisTopic, style: text.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('YOUR PATH', style: text.labelSmall),
              const SizedBox(height: AppSpacing.md),
              _Step(1, 'Pre-Assessment',
                  'A short check of what you already know', active: true),
              _Step(2, 'Learning', 'Focused lessons for your level'),
              _Step(3, 'Practice', 'Exercises to make it stick'),
              _Step(4, 'Post-Assessment', 'See how much you improved',
                  last: true),
            ],
          ),
        ),
        _Footer(minutes: _minutes, questions: topic.preAssessmentLength),
      ],
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.subtitle,
      {this.active = false, this.last = false});

  final int number;
  final String title;
  final String subtitle;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = active ? AppColors.textPrimary : AppColors.textSecondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: text.labelMedium?.copyWith(
                    color: active ? AppColors.onPrimary : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1, color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            style: text.titleLarge?.copyWith(color: fg)),
                      ),
                      if (active) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('START HERE',
                              style: text.labelSmall
                                  ?.copyWith(color: AppColors.onPrimary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.minutes, required this.questions});

  final int minutes;
  final int questions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH, AppSpacing.lg, AppSpacing.pageH, AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () {},
            child: const Text('Start with a quick check'),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Derived, not hardcoded — the estimate stays honest as the topic
          // gains sub-skills.
          Text(
            '$questions questions · about $minutes minutes · not graded',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
