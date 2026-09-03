import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/vocabulary/word_card.dart';
import '../../../shared/widgets/bangla_text.dart';

/// One word, taught (SPEC §8).
///
/// Every section below the meaning is optional and simply absent when the
/// content does not carry it. The spec's own warning is against information
/// overload: a card padded with empty headings teaches the learner to skim
/// past the headings that matter.
class WordCardView extends StatelessWidget {
  const WordCardView(this.card, {super.key});

  final WordCard card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(card.word, style: text.displaySmall)),
            if (card.pos case final pos?) ...[
              const SizedBox(width: AppSpacing.md),
              _Chip(pos),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        BanglaText(card.bn, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xl),

        // The sentence carries more than the gloss does: it shows the word
        // doing its job, which is what the learner has to reproduce.
        _Section(
          label: 'IN A SENTENCE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.example.en, style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              BanglaText(card.example.bn, style: text.bodyMedium),
            ],
          ),
        ),

        if (card.usage case final usage?) ...[
          const SizedBox(height: AppSpacing.lg),
          _Section(
            label: 'HOW IT IS USED',
            child: Text(usage, style: text.bodyLarge),
          ),
        ],

        if (card.synonyms.isNotEmpty || card.antonyms.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (card.synonyms.isNotEmpty)
                Expanded(
                  child: _WordList(label: 'SAME', words: card.synonyms),
                ),
              if (card.synonyms.isNotEmpty && card.antonyms.isNotEmpty)
                const SizedBox(width: AppSpacing.md),
              if (card.antonyms.isNotEmpty)
                Expanded(
                  child: _WordList(label: 'OPPOSITE', words: card.antonyms),
                ),
            ],
          ),
        ],

        if (card.collocations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Section(
            label: 'GOES WITH',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [for (final c in card.collocations) _Chip(c)],
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _WordList extends StatelessWidget {
  const _WordList({required this.label, required this.words});

  final String label;
  final List<String> words;

  @override
  Widget build(BuildContext context) => _Section(
    label: label,
    child: Text(words.join(', '), style: Theme.of(context).textTheme.bodyLarge),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.divider,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.textOnMuted),
    ),
  );
}
