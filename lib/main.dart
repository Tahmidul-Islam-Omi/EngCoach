import 'package:flutter/material.dart';

import 'app/theme/app_colors.dart';
import 'app/theme/app_spacing.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/app_typography.dart';

void main() {
  runApp(const EngCoachApp());
}

class EngCoachApp extends StatelessWidget {
  const EngCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EngCoach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _ThemeCheck(),
    );
  }
}

/// Temporary. Renders one of each themed element so the theme — especially
/// the Bengali fallback — can be checked on a real device. Deleted once the
/// router and real screens land.
class _ThemeCheck extends StatelessWidget {
  const _ThemeCheck();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Theme check')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageH),
        children: [
          Text('Present Simple', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Rules for correct sentences', style: text.bodySmall),
          const SizedBox(height: AppSpacing.xl),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LEARNING EVIDENCE', style: text.labelSmall),
                  const SizedBox(height: AppSpacing.md),
                  // Mixed Bangla + English in ONE string and ONE style —
                  // if the fallback is wired correctly this renders fully.
                  Text(
                    'He / she / it-এর ক্ষেত্রে verb-এর শেষে -s যোগ হয়।',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'সম্পূর্ণ বাংলা ব্যাখ্যা এখানে দেখানো হবে।',
                    style: AppTypography.banglaBlock,
                  ),
                  const Divider(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Improvement', style: text.bodyMedium),
                      Text('+25 pp',
                          style: AppTypography.numericLarge
                              .copyWith(color: AppColors.success)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              _Badge('NOT STARTED', AppStatusColors.notStarted),
              _Badge('TESTED', AppStatusColors.tested),
              _Badge('LEARNING', AppStatusColors.learning),
              _Badge('COMPLETED', AppStatusColors.completed),
              _Badge('MASTERED', AppStatusColors.mastered),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton(onPressed: () {}, child: const Text('Start review')),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: () {}, child: const Text('Show 21 more')),
          const SizedBox(height: AppSpacing.md),
          const TextField(decoration: InputDecoration(hintText: 'Email')),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.colors);

  final String label;
  final AppColorPair colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: colors.foreground),
      ),
    );
  }
}
