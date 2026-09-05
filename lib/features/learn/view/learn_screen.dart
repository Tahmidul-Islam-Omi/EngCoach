import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

/// Section list — the entry point into every learning track (SPEC §5).
///
/// Sections not yet built are shown but marked, rather than hidden: the
/// scope of the product stays visible without leading anyone into a dead end.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          0,
          AppSpacing.pageH,
          AppSpacing.xxl,
        ),
        children: [
          Text('Choose a section to begin.', style: text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'Grammar',
            subtitle: 'Rules for correct sentences',
            icon: Icons.spellcheck_rounded,
            onTap: () => context.go(Routes.grammar),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Vocabulary',
            subtitle: 'Learn and retain new words',
            icon: Icons.style_outlined,
            onTap: () => context.go(Routes.vocabulary),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionCard(
            title: 'Writing',
            subtitle: 'Build clear written English',
            icon: Icons.edit_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionCard(
            title: 'Speaking',
            subtitle: 'Practise saying it out loud',
            icon: Icons.mic_none_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionCard(
            title: 'Reading',
            subtitle: 'Understand longer texts',
            icon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionCard(
            title: 'Listening',
            subtitle: 'Follow spoken English',
            icon: Icons.headphones_outlined,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Null while a section is still being built.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ready = onTap != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 22, color: AppColors.textOnMuted),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleLarge?.copyWith(
                        color: ready
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Says what is true rather than showing a padlock. A lock reads
              // as something the learner could unlock; these are simply not
              // built yet.
              if (ready)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                )
              else
                Text('Coming soon', style: text.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
