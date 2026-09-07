import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/models/topic.dart';
import '../../../shared/widgets/app_list_row.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/improvement_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../model/progress_report.dart';
import '../viewmodel/progress_view_model.dart';

/// The evidence screen (SPEC §4.4, §10.1).
///
/// Home answers "what should I learn today?". This answers the harder
/// question — whether any of it worked — and every number on it came from a
/// check the learner sat. Nothing here is estimated, and the three things
/// the spec asks for that nothing records (time invested, retention, the
/// error notebook) are simply absent rather than filled in with a guess.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(progressReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: AsyncView(
        value: report,
        onRetry: () => ref.invalidate(progressReportProvider),
        data: (data) => _Report(data),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report(this.report);

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.sm,
        AppSpacing.pageH,
        AppSpacing.xxxl,
      ),
      children: [
        if (report.overallBefore case final before?)
          if (report.overallAfter case final after?)
            ImprovementCard(
              before: before,
              after: after,
              caption: report.reCheckedCount == 1
                  ? 'On the same rules, asked differently.'
                  : 'Across ${report.reCheckedCount} re-checked topics, on '
                        'the same rules asked differently.',
            )
          else
            const _NoEvidenceYet()
        else
          const _NoEvidenceYet(),

        if (report.topics.isNotEmpty || report.notStarted.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Label(
            report.topics.length > 1 ? 'Grammar · weakest first' : 'Grammar',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final topic in report.topics) ...[
            _TopicCard(topic),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (report.notStarted.isNotEmpty) _NotStarted(report.notStarted),
        ],

        if (report.vocabulary case final vocabulary?) ...[
          const SizedBox(height: AppSpacing.xl),
          const _Label('Vocabulary'),
          const SizedBox(height: AppSpacing.sm),
          _VocabularyCard(vocabulary),
        ],

        if (report.weakAreas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Label('Still to work on · ${report.weakAreas.length}'),
          const SizedBox(height: AppSpacing.sm),
          for (final area in report.weakAreas) ...[
            AppListRow(
              icon: Icons.warning_amber_rounded,
              title: area.title,
              subtitle: area.context,
              onTap: () => context.push(area.route),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],

        if (report.checks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const _Label('Every check you have taken'),
          const SizedBox(height: AppSpacing.sm),
          _Checks(report.checks),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

/// Shown until a topic has been checked twice.
///
/// A first check is a starting point, not a result — putting 60% under a
/// heading like "your progress" would present the measurement that decided
/// what to teach as if it were the outcome of teaching it.
class _NoEvidenceYet extends StatelessWidget {
  const _NoEvidenceYet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No before and after yet', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Finish a topic’s lessons and take its second check. That pair is '
            'what proves you improved.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- grammar

class _TopicCard extends StatelessWidget {
  const _TopicCard(this.topic);

  final TopicReport topic;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.topic(topic.topicId)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(topic.title, style: text.titleLarge)),
                  if (topic.gain case final gain?) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _GainPill(gain),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(topic.status),
                ],
              ),
              if (topic.before case final before?) ...[
                const SizedBox(height: AppSpacing.md),
                _ScoreRail(label: 'Before', percent: before, muted: true),
                if (topic.after case final after?) ...[
                  const SizedBox(height: AppSpacing.xs + 1),
                  _ScoreRail(label: 'After', percent: after, muted: false),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(_partsLine(topic), style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

String _partsLine(TopicReport topic) {
  if (topic.partsWeak == 0) {
    return topic.after == null
        ? 'Nothing came back weak.'
        : 'Every part is clear.';
  }
  final tail = topic.after == null ? 'came back weak' : 'still weak';
  return '${topic.partsWeak} of ${topic.partsTotal} parts $tail.';
}

/// One check's score, as a labelled bar.
///
/// A bar as well as the number because the two rows exist to be compared,
/// and two lengths read as a comparison faster than two percentages do.
class _ScoreRail extends StatelessWidget {
  const _ScoreRail({
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

    return Row(
      children: [
        SizedBox(
          // Wide enough for the longest label at this size. Both rows share
          // it so the two bars start at the same x — they exist to be
          // compared, and bars that do not line up cannot be.
          width: 52,
          child: Text(
            label.toUpperCase(),
            // One line, always. At 46 this wrapped "SECOND" to "SECON / D",
            // which broke the row's height and read as a typo.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: AppSizes.barHeight,
              backgroundColor: AppColors.divider,
              color: muted ? AppColors.controlOutline : AppColors.primary,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: AppTypography.numeric.copyWith(
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _GainPill extends StatelessWidget {
  const _GainPill(this.gain);

  final int gain;

  @override
  Widget build(BuildContext context) {
    final up = gain > 0;
    final colors = up ? AppStatusColors.completed : AppStatusColors.notStarted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        // Signed, because the figure only means anything as a change.
        '${up ? '+' : ''}$gain',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.foreground),
      ),
    );
  }
}

class _NotStarted extends StatelessWidget {
  const _NotStarted(this.topics);

  final List<Topic> topics;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.grammar),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topics.length == 1
                    ? '1 topic not started'
                    : '${topics.length} topics not started',
                style: text.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [for (final t in topics) t.title].join(', '),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- vocabulary

class _VocabularyCard extends StatelessWidget {
  const _VocabularyCard(this.report);

  final VocabularyReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Level ${report.level}', style: text.titleLarge),
              ),
              // "Cleared", not "Completed": the vocabulary module says
              // cleared everywhere else, and completed is grammar's word for
              // a different thing.
              if (report.cleared) const _ClearedBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Ladder(
            level: report.level,
            topLevel: report.topLevel,
            cleared: report.cleared,
          ),
          if (report.areas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const _Label('Before and after'),
            const SizedBox(height: AppSpacing.xs),
            for (final (i, area) in report.areas.indexed)
              _AreaRow(area: area, first: i == 0),
          ],
        ],
      ),
    );
  }
}

class _ClearedBadge extends StatelessWidget {
  const _ClearedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: 3,
    ),
    decoration: BoxDecoration(
      color: AppStatusColors.completed.background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      'CLEARED',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppStatusColors.completed.foreground,
      ),
    ),
  );
}

/// The four rungs, with the one the learner is on filled.
///
/// The ladder rather than a percentage: level is the shape this module
/// actually has, and "Level 2 of 4" is the thing a learner recognises.
class _Ladder extends StatelessWidget {
  const _Ladder({
    required this.level,
    required this.topLevel,
    required this.cleared,
  });

  final int level;
  final int topLevel;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        for (var rung = 1; rung <= topLevel; rung++) ...[
          if (rung > 1) const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Container(
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rung <= (cleared ? level : level - 1)
                    ? AppColors.primary
                    : rung == level
                    ? AppColors.textOnMuted
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '$rung',
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: rung <= level
                      ? AppColors.onPrimary
                      : AppColors.textOnMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.area, required this.first});

  final VocabAreaReport area;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 1),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(area.title, style: text.bodyMedium)),
          const SizedBox(width: AppSpacing.sm),
          // Counts, not percentages: the first measurement is a single
          // question per area, and 0% / 100% would dress that up as
          // something it is not.
          Text(
            '${area.beforeCorrect}/${area.beforeTotal}',
            style: AppTypography.numeric,
          ),
          if (area.hasAfter) ...[
            const SizedBox(width: AppSpacing.xs + 2),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              '${area.afterCorrect}/${area.afterTotal}',
              style: AppTypography.numeric.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- weak areas

// ----------------------------------------------------------------- checks

class _Checks extends StatelessWidget {
  const _Checks(this.checks);

  final List<CheckEvent> checks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (final (i, check) in checks.indexed)
            _CheckRow(check: check, last: i == checks.length - 1),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.last});

  final CheckEvent check;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _shortDate(check.takenAt),
              style: AppTypography.numeric,
            ),
          ),
          // The spine, with a dot at this entry. Drawn rather than an icon so
          // it joins up between rows.
          SizedBox(
            width: 13,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!last)
                  const Positioned(
                    top: 8,
                    bottom: 0,
                    child: SizedBox(
                      width: 1,
                      child: ColoredBox(color: AppColors.border),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    check.title,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(check.detail, style: text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Day and month, without the year.
///
/// No intl dependency for one date format, and the year is noise on a list
/// that is almost always weeks long rather than years.
String _shortDate(DateTime at) => '${at.day} ${_months[at.month - 1]}';
