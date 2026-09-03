import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/note.dart';

/// The way into the vocabulary module.
///
/// Says what the check is for before asking anyone to sit it: a diagnostic
/// that opens without explaining itself reads as a test to be passed, which
/// is the opposite of what it is.
class VocabularyOverviewScreen extends StatelessWidget {
  const VocabularyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary')),
      body: Column(
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
                Text('Learn and retain new words', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The check finds the level you are already at and the areas '
                  'that need the most work. It stops as soon as it knows, so '
                  'it is short.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('WHAT IT LOOKS AT', style: text.labelSmall),
                const SizedBox(height: AppSpacing.md),
                const _Point(
                  icon: Icons.stairs_outlined,
                  title: 'Your level',
                  body:
                      'Four levels, from everyday words to the ones a '
                      'newspaper assumes you know.',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Point(
                  icon: Icons.tune_rounded,
                  title: 'Where the gaps are',
                  body:
                      'Meaning, usage, opposites, word pairs and word '
                      'building are checked separately, so the lessons skip '
                      'what is already solid.',
                ),
                const SizedBox(height: AppSpacing.xl),
                Note(
                  icon: Icons.info_outline_rounded,
                  child: Text(
                    'Nothing is explained during the check. The answers come '
                    'afterwards, in the lessons.',
                    style: text.bodySmall,
                  ),
                ),
              ],
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
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: () => context.push(Routes.vocabularyCheck),
                child: const Text('Start the check'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge),
              const SizedBox(height: 2),
              Text(body, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
