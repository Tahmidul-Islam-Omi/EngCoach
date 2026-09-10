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
import '../../../shared/widgets/bangla_text.dart';
import '../../../shared/widgets/section_label.dart';
import '../model/home_state.dart';
import '../model/next_step.dart';
import '../viewmodel/home_view_model.dart';

/// The daily control center (SPEC §9).
///
/// Everything on it is read from what the learner's own checks recorded —
/// there is no streak, no daily goal and no review queue, because nothing
/// writes the data those would need. One hero card always offers exactly one
/// next action, so the screen answers "what should I learn today?" with an
/// answer rather than a menu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeStateProvider);

    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: state,
          onRetry: () => ref.invalidate(homeStateProvider),
          data: (home) => _Home(home),
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home(this.home);

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    final hero = _Hero.of(home.next);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.lg,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      children: [
        _Greeting(home.next),
        const SizedBox(height: AppSpacing.lg),
        _HeroCard(hero: hero, onTap: () => _open(context, hero.route)),

        // The first-run card is an explanation, not a task list: someone who
        // has never taken a check needs to know what one is before they will
        // start it.
        if (home.next is StartFirstTopic) ...[
          const SizedBox(height: AppSpacing.lg),
          const _FirstRunNote(),
          const SizedBox(height: AppSpacing.lg),
          const _HowItWorks(),
        ],

        if (home.alsoInProgress case final other?)
          if (_Hero.of(other) case final second) ...[
            const SizedBox(height: AppSpacing.xl),
            _Group(
              label: 'Also in progress',
              children: [
                AppListRow(
                  icon: second.icon,
                  title: second.title,
                  subtitle: second.meta,
                  onTap: () => _open(context, second.route),
                ),
              ],
            ),
          ],

        if (home.weakAreas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Group(
            label: 'Your weak areas',
            children: [
              for (final area in home.weakAreas)
                AppListRow(
                  icon: Icons.warning_amber_rounded,
                  title: area.title,
                  subtitle: area.context,
                  onTap: () => _open(context, area.route),
                ),
            ],
          ),
        ],

        if (home.finished.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Group(
            label: 'Finished',
            children: [
              for (final topic in home.finished)
                AppListRow(
                  icon: Icons.check_rounded,
                  title: topic.title,
                  subtitle: 'Completed',
                  onTap: () => _open(context, Routes.topic(topic.id)),
                ),
            ],
          ),
        ],

        if (home.untouched.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Group(
            label: 'Or start something new',
            children: [
              AppListRow(
                icon: Icons.auto_stories_outlined,
                title: _untouchedTitle(home.untouched),
                subtitle: _untouchedSubtitle(home.untouched),
                onTap: () => _open(context, Routes.grammar),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        _Group(label: 'So far', children: [_StatsStrip(home.stats)]),
      ],
    );
  }
}

String _untouchedTitle(List<Topic> topics) => topics.length == 1
    ? '1 grammar topic untouched'
    : '${topics.length} grammar topics untouched';

String _untouchedSubtitle(List<Topic> topics) {
  final named = topics.take(2).map((t) => t.title).join(', ');
  final rest = topics.length - 2;
  return rest > 0 ? '$named, and $rest more' : named;
}

/// Opens a destination.
///
/// Tab destinations use [GoRouter.go] and the focused flows use `push`, for
/// the reason the router gives: the topic and vocabulary screens sit outside
/// the shell so a bottom nav bar cannot invite anyone out of a check.
///
/// Nothing is refreshed on the way back. The screens that write progress
/// invalidate what Home reads, so it is already current whether the learner
/// popped back here or arrived from the Learn tab.
void _open(BuildContext context, String route) {
  if (route == Routes.learn ||
      route == Routes.grammar ||
      route == Routes.progress) {
    context.go(route);
    return;
  }

  context.push(route);
}

// ------------------------------------------------------------------ header

class _Greeting extends StatelessWidget {
  const _Greeting(this.next);

  final NextStep next;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // No name: sign-in collects a phone number and nothing else, and
    // "Hi, <phone>" is worse than a greeting that cannot be wrong.
    final (title, subtitle) = switch (next) {
      StartFirstTopic() => ('Start here', 'Two sections are open. Pick one.'),
      ContinueTopic(:final title) => (
        'Welcome back',
        'You left off in $title.',
      ),
      ContinueVocabulary(:final level) => (
        'Welcome back',
        'You left off in Vocabulary Level $level.',
      ),
      _ when next.isWorkInProgress => (
        'Welcome back',
        'One thing is waiting for you.',
      ),
      _ => ('All caught up', 'Nothing is waiting for you today.'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.headlineMedium),
        const SizedBox(height: 2),
        Text(subtitle, style: text.bodySmall),
      ],
    );
  }
}

// -------------------------------------------------------------------- hero

/// The copy for one [NextStep].
///
/// Kept apart from the widget so the wording of all ten states can be read in
/// one place, and so a new step cannot be added without writing its copy —
/// the switch is exhaustive.
class _Hero {
  const _Hero({
    required this.label,
    required this.title,
    required this.meta,
    required this.cta,
    required this.route,
    required this.icon,
    this.done,
    this.total,
  });

  factory _Hero.of(NextStep step) => switch (step) {
    StartFirstTopic() => const _Hero(
      label: 'Start here',
      title: 'Ready to learn your first topic?',
      meta:
          'Pick a section, choose a topic, and a short check will find your '
          'starting point. No long test to begin.',
      cta: 'Choose a topic',
      route: Routes.learn,
      icon: Icons.flag_outlined,
    ),
    ContinueTopic(
      :final topicId,
      :final title,
      :final done,
      :final total,
      :final nextArea,
    ) =>
      _Hero(
        label: 'Pick up where you left off',
        title: title,
        meta: '$done of $total areas done · next up “$nextArea”',
        cta: 'Continue',
        route: Routes.learningPath(topicId),
        icon: Icons.spellcheck_rounded,
        done: done,
        total: total,
      ),
    StartTopicLearning(:final topicId, :final title) => _Hero(
      label: 'Your check is done',
      title: title,
      meta: 'Your lessons are ready — they cover only what the check found.',
      cta: 'Start learning',
      route: Routes.learningPath(topicId),
      icon: Icons.spellcheck_rounded,
    ),
    TakeTopicPostCheck(:final topicId, :final title) => _Hero(
      label: 'Ready to prove it',
      title: title,
      meta:
          'You have practised every area. The second check measures what '
          'changed.',
      cta: 'Take the check',
      route: Routes.postAssessment(topicId),
      icon: Icons.fact_check_outlined,
    ),
    StartNewTopic(:final topicId, :final title) => _Hero(
      label: 'Next step',
      title: title,
      meta: 'A short check will find your starting point in this topic.',
      cta: 'Start this topic',
      route: Routes.topic(topicId),
      icon: Icons.spellcheck_rounded,
    ),
    ContinueVocabulary(:final level, :final done, :final total) => _Hero(
      label: 'Pick up where you left off',
      title: 'Vocabulary · Level $level',
      meta: '$done of $total word sets finished',
      cta: 'Continue',
      route: Routes.vocabularyPath,
      icon: Icons.style_outlined,
      done: done,
      total: total,
    ),
    TakeVocabularyFinalCheck(:final level) => _Hero(
      label: 'Ready to prove it',
      title: 'Vocabulary · Level $level',
      meta:
          'Every word set is finished. The final check measures what '
          'changed.',
      cta: 'Take the check',
      route: Routes.vocabularyFinalCheck,
      icon: Icons.fact_check_outlined,
    ),
    CheckNextVocabularyLevel(:final level) => _Hero(
      label: 'Next step',
      title: 'Check your vocabulary level again',
      meta:
          'You cleared the level below. A short check will place you in '
          'Level $level.',
      cta: 'Start the check',
      route: Routes.vocabularyCheck,
      icon: Icons.style_outlined,
    ),
    StartVocabulary() => const _Hero(
      label: 'Next step',
      title: 'Vocabulary',
      meta: 'A short check will find your level and pick what to teach you.',
      cta: 'Start the check',
      route: Routes.vocabularyCheck,
      icon: Icons.style_outlined,
    ),
    NothingLeft() => const _Hero(
      label: 'All caught up',
      title: 'You have finished everything built so far.',
      meta: 'More sections are on the way. Everything you have done is saved.',
      cta: 'See your progress',
      route: Routes.progress,
      icon: Icons.emoji_events_outlined,
    ),
  };

  final String label;
  final String title;
  final String meta;
  final String cta;
  final String route;
  final IconData icon;

  /// Set only where there is real work to count.
  final int? done;
  final int? total;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.hero, required this.onTap});

  final _Hero hero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hero.label.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: AppColors.onPrimaryMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hero.title,
                style: text.headlineSmall?.copyWith(color: AppColors.onPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hero.meta,
                style: text.bodySmall?.copyWith(color: AppColors.onPrimaryBody),
              ),
              if (hero.done case final done?)
                if (hero.total case final total? when total > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: done / total,
                      minHeight: AppSizes.barHeight,
                      backgroundColor: AppColors.textSecondary,
                      color: AppColors.onPrimaryBody,
                    ),
                  ),
                ],
              const SizedBox(height: AppSpacing.lg),
              _HeroButton(hero.cta),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's own call to action.
///
/// Not a real button: the whole card is the tap target, and a nested
/// [InkWell] would put a second focusable stop on one action.
class _HeroButton extends StatelessWidget {
  const _HeroButton(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.minTapTarget,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.arrow_forward_rounded, size: 18),
      ],
    ),
  );
}

// ------------------------------------------------------------- first run

class _FirstRunNote extends StatelessWidget {
  const _FirstRunNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    // The one thing worth saying in Bangla on the very first screen: that
    // there is no long entry test standing in the way.
    child: const BanglaText(
      'প্রথমে ছোট একটা চেক। কোথা থেকে শুরু করবেন, সেটা আমরা বের করে দেব।',
    ),
  );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) => const _Group(
    label: 'How EngCoach works',
    children: [
      _Step(1, 'Check', 'A quick pre-assessment finds what you already know.'),
      _Step(
        2,
        'Learn & practise',
        'Short lessons and exercises for your level.',
      ),
      _Step(3, 'See progress', 'A second check shows how much you improved.'),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.detail);

  final int number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 1),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: text.labelMedium?.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                const SizedBox(height: 2),
                Text(detail, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- rows

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionLabel(label),
      const SizedBox(height: AppSpacing.sm),
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ],
  );
}

// ------------------------------------------------------------------ stats

class _StatsStrip extends StatelessWidget {
  const _StatsStrip(this.stats);

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final gain = stats.grammarGain;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      // Intrinsic, so the hairlines between cells run the full height of the
      // tallest one. A stretched Row inside a ListView has no height to
      // stretch to.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stat(
              value: '${stats.topicsStarted}',
              suffix: '/${stats.topicsTotal}',
              label: 'Grammar topics started',
            ),
            const _Divider(),
            _Stat(
              value: stats.vocabLevel == null ? '—' : '${stats.vocabLevel}',
              label: 'Vocab level',
            ),
            const _Divider(),
            _Stat(
              // Signed, because the number only means something as a change.
              value: gain == null ? '—' : '${gain > 0 ? '+' : ''}$gain',
              label: 'Grammar gain',
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 1, child: ColoredBox(color: AppColors.divider));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.suffix});

  final String value;
  final String? suffix;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppTypography.numericLarge),
                if (suffix case final s?)
                  Text(
                    s,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
