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
            badge: 'START',
            onTap: () => context.go(Routes.grammar),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionCard(
            title: 'Vocabulary',
            subtitle: 'Learn and retain new words',
            icon: Icons.style_outlined,
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
          const SizedBox(height: AppSpacing.xl),
          const _ComingSoon(),
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
    this.badge,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;

    final titleColor = enabled
        ? AppColors.textPrimary
        : AppColors.textSecondary;

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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: text.titleLarge?.copyWith(color: titleColor),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _Pill(badge!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              Icon(
                enabled
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppColors.onPrimary),
    ),
  );
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _NoticeBox(
      child: Column(
        children: [
          Text('COMING SOON', style: text.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('Reading · Listening', style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// Outlined container for not-yet-available content.
class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: child,
  );
}
