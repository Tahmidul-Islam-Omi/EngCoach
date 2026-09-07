import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_list_row.dart';

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
          for (final (i, s) in _sections.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            AppListRow(
              title: s.title,
              subtitle: s.subtitle,
              icon: s.icon,
              large: true,
              onTap: s.route == null ? null : () => context.go(s.route!),
              // Says what is true rather than showing a padlock. A lock reads
              // as something the learner could unlock; these are simply not
              // built yet.
              trailing: s.route == null
                  ? Text('Coming soon', style: text.labelSmall)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

typedef _Section = ({
  String title,
  String subtitle,
  IconData icon,

  /// Null while the section is still being built.
  String? route,
});

const _sections = <_Section>[
  (
    title: 'Grammar',
    subtitle: 'Rules for correct sentences',
    icon: Icons.spellcheck_rounded,
    route: Routes.grammar,
  ),
  (
    title: 'Vocabulary',
    subtitle: 'Learn and retain new words',
    icon: Icons.style_outlined,
    route: Routes.vocabulary,
  ),
  (
    title: 'Writing',
    subtitle: 'Build clear written English',
    icon: Icons.edit_outlined,
    route: null,
  ),
  (
    title: 'Speaking',
    subtitle: 'Practise saying it out loud',
    icon: Icons.mic_none_rounded,
    route: null,
  ),
  (
    title: 'Reading',
    subtitle: 'Understand longer texts',
    icon: Icons.menu_book_outlined,
    route: null,
  ),
  (
    title: 'Listening',
    subtitle: 'Follow spoken English',
    icon: Icons.headphones_outlined,
    route: null,
  ),
];
