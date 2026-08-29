import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/lesson_block.dart';
import '../../../shared/widgets/bangla_text.dart';
import '../../../shared/widgets/markup_text.dart';

/// Renders one authored lesson block.
///
/// The switch is exhaustive over the sealed [LessonBlock] hierarchy, so
/// adding a seventh block type is a compile error here rather than a blank
/// space in a lesson.
class LessonBlockView extends StatelessWidget {
  const LessonBlockView(this.block, {super.key});

  final LessonBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
        TextBlock(:final text) => _Paragraph(text),
        PatternBlock(:final text, :final highlight) =>
          _Pattern(text: text, highlight: highlight),
        TableBlock(:final headers, :final rows) =>
          _Comparison(headers: headers, rows: rows),
        ExamplesBlock(:final items) => _Examples(items),
        CalloutBlock(:final label, :final text) =>
          _Callout(label: label, text: text),
        BanglaBlock(:final label, :final text) =>
          _Bangla(label: label, text: text),
      };
}

// ------------------------------------------------------------------- text

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => MarkupText(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      );
}

// ---------------------------------------------------------------- pattern

/// The rule stated as a formula, with its consequence on the end.
///
/// Set apart rather than run into the prose: this is the one line a learner
/// is meant to carry away, and it is what they will scan back for.
class _Pattern extends StatelessWidget {
  const _Pattern({required this.text, required this.highlight});

  final String text;

  /// The tail — "+ s", "no change". Short by authoring convention.
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      // Wraps rather than clips: some patterns are long, and a rule the
      // learner cannot finish reading is worse than one on two lines.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          MarkupText(
            text,
            style: theme.titleMedium?.copyWith(color: AppColors.onPrimary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              highlight,
              style: theme.labelMedium?.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ table

/// Two columns, side by side — every authored table contrasts one form
/// against another, which is why the header row is emphasised and the
/// columns are equal width.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          _Row(
            cells: headers,
            style: theme.labelMedium?.copyWith(
              color: AppColors.textOnMuted,
              fontWeight: FontWeight.w700,
            ),
            background: AppColors.divider,
          ),
          for (var i = 0; i < rows.length; i++)
            _Row(
              cells: rows[i],
              style: theme.bodyMedium,
              // Hairline between rows, never under the last one.
              border: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.cells,
    required this.style,
    this.background,
    this.border = false,
  });

  final List<String> cells;
  final TextStyle? style;
  final Color? background;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: border
            ? const Border(bottom: BorderSide(color: AppColors.divider))
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: MarkupText(cells[i], style: style),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- examples

/// Sentences with the taught word picked out.
///
/// The highlight is a substring of the sentence — every authored item was
/// checked — so it is marked in place rather than repeated beside it.
class _Examples extends StatelessWidget {
  const _Examples(this.items);

  final List<ExampleItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _Example(items[i]),
        ],
      ],
    );
  }
}

class _Example extends StatelessWidget {
  const _Example(this.item);

  final ExampleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final at = item.text.indexOf(item.highlight);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.controlOutline,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: at < 0
              // Should not happen — every authored highlight was verified
              // present — but a lesson must never lose its sentence over it.
              ? MarkupText(item.text, style: theme.bodyMedium)
              : Text.rich(
                  TextSpan(
                    style: theme.bodyMedium,
                    children: [
                      TextSpan(text: item.text.substring(0, at)),
                      TextSpan(
                        text: item.highlight,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                      TextSpan(
                        text: item.text.substring(at + item.highlight.length),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- callout

/// The mistake to avoid. Warning-toned, because it is always about an error
/// the learner is likely to make.
class _Callout extends StatelessWidget {
  const _Callout({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label.toUpperCase(),
                style: theme.labelSmall?.copyWith(color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MarkupText(
            text,
            style: theme.bodyMedium?.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- bangla

/// The Bangla explanation — the reason the product exists (SPEC §4.2).
///
/// Given its own visual treatment rather than being another paragraph: a
/// learner who did not follow the English should be able to find this by
/// scanning, without reading what came before.
class _Bangla extends StatelessWidget {
  const _Bangla({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.labelMedium?.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          BanglaText(text),
        ],
      ),
    );
  }
}
