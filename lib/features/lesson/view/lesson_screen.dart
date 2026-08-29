import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/lesson.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/async_view.dart';
import 'lesson_block_view.dart';

/// One sub-skill's lesson.
///
/// A single scroll rather than paged blocks: a lesson is six short pieces
/// that build one idea, and making someone tap through them would break the
/// rule apart from the examples that explain it. Scrolling also lets them
/// look back at the pattern while reading the examples.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({
    required this.topicId,
    required this.subSkillId,
    super.key,
  });

  final String topicId;
  final String subSkillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = ref.watch(topicProvider(topicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Lesson')),
      body: AsyncView(
        value: topic,
        onRetry: () => ref.invalidate(topicProvider(topicId)),
        data: (t) {
          final lesson = t.lessons
              .where((l) => l.subSkillId == subSkillId)
              .firstOrNull;

          // A sub-skill with no authored lesson is a content fault, not a
          // crash: say so plainly rather than throwing on firstWhere.
          if (lesson == null) {
            return const _Missing();
          }

          return _Body(lesson: lesson);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
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
              Text('LESSON', style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(lesson.title, style: text.headlineLarge),
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < lesson.blocks.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                LessonBlockView(lesson.blocks[i]),
              ],
            ],
          ),
        ),
        _Footer(practiceCount: lesson.practice.length),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.practiceCount});

  /// Shown so the learner knows reading is not the end of it. The practice
  /// itself is not built yet.
  final int practiceCount;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Becomes "Practice this" once the exercises exist. Until then
            // it goes where it says it goes.
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done for now'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$practiceCount practice questions are coming for this lesson',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 32,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "This lesson isn't ready yet.",
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try another sub-skill for now.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
