import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/vocabulary/vocab_chunk.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../../shared/widgets/async_view.dart';
import '../viewmodel/vocab_plan_view_model.dart';
import 'word_card_view.dart';

/// One chunk's words, one at a time.
///
/// Paged rather than scrolled, unlike a grammar lesson. A lesson is six short
/// pieces building one idea, so splitting it would break the rule apart from
/// its examples. A word set is six independent words, and meeting them one at
/// a time is what makes the count — "word 3 of 6" — mean anything.
class VocabWordsScreen extends ConsumerStatefulWidget {
  const VocabWordsScreen({required this.chunkId, super.key});

  final String chunkId;

  @override
  ConsumerState<VocabWordsScreen> createState() => _VocabWordsScreenState();
}

class _VocabWordsScreenState extends ConsumerState<VocabWordsScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(vocabPlanProvider);

    // Reached only from the plan, so a missing plan means the check was
    // cleared out from under this route rather than a state to design for.
    if (plan == null) return const _Missing();

    final level = ref.watch(vocabLevelProvider(plan.level));

    return Scaffold(
      appBar: AppBar(title: const Text('Words')),
      body: AsyncView(
        value: level,
        onRetry: () => ref.invalidate(vocabLevelProvider(plan.level)),
        data: (l) {
          final chunk = l.chunks
              .where((c) => c.id == widget.chunkId)
              .firstOrNull;

          // A plan naming a chunk this level does not carry is a content
          // fault, not a crash: say so plainly rather than throwing.
          if (chunk == null || chunk.words.isEmpty) return const _Missing();

          final index = _index.clamp(0, chunk.words.length - 1);

          return _Body(
            chunk: chunk,
            index: index,
            onBack: () => setState(() => _index = index - 1),
            onNext: () => setState(() => _index = index + 1),
            // Reading six cards is not evidence of anything, so the set is
            // not marked done here — the practice does that.
            practiceCount: chunk.practice.length,
            onPractise: () => context.push(Routes.vocabularyPractice(chunk.id)),
            onLeave: () => context.pop(),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.chunk,
    required this.index,
    required this.onBack,
    required this.onNext,
    required this.practiceCount,
    required this.onPractise,
    required this.onLeave,
  });

  final VocabChunk chunk;
  final int index;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// Shown so the learner knows reading is not the end of it.
  final int practiceCount;

  final VoidCallback onPractise;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = chunk.words.length;
    final isLast = index == total - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: (index + 1) / total,
                  minHeight: AppSizes.barHeight,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Word ${index + 1} of $total', style: text.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            // Keyed by word so the scroll position resets between cards
            // rather than carrying a long card's offset onto a short one.
            key: ValueKey(chunk.words[index].word),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.xl,
              AppSpacing.pageH,
              AppSpacing.xxxl,
            ),
            children: [WordCardView(chunk.words[index])],
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
          // Outside the tab shell nothing else supplies the bottom inset.
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (index > 0) ...[
                      OutlinedButton(
                        // The theme sizes outlined buttons full-bleed, which
                        // is an infinite width inside a Row.
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(
                            AppSizes.secondaryButtonWidth,
                            AppSizes.buttonHeight,
                          ),
                        ),
                        onPressed: onBack,
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: FilledButton(
                        // Reading then doing: the practice is where the words
                        // actually get tested, so it is the primary action on
                        // the last card.
                        onPressed: isLast && practiceCount > 0
                            ? onPractise
                            : isLast
                            ? onLeave
                            : onNext,
                        child: Text(
                          !isLast
                              ? 'Next word'
                              : practiceCount > 0
                              ? 'Practise these — $practiceCount '
                                    '${practiceCount == 1 ? 'question' : 'questions'}'
                              : 'Done',
                        ),
                      ),
                    ),
                  ],
                ),
                if (isLast && practiceCount > 0)
                  TextButton(
                    onPressed: onLeave,
                    child: const Text('Done for now'),
                  ),
              ],
            ),
          ),
        ),
      ],
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
        child: Text(
          'These words are not available yet.',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
