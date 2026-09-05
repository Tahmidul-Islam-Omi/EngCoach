import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/extensions/phone_format.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/session_service.dart';
import '../viewmodel/app_version.dart';

/// Account and subscription.
///
/// Ordered least dangerous to most: who you are, what you pay, the app
/// itself, and only then the two actions that end something. Nothing here
/// repeats a number that Progress owns — a second copy would drift out of
/// step with the screen that measured it.
///
/// Sign-in has no gate in front of it yet — the app is browsable signed out —
/// so this is also the way in and out of the flow while it is being tested.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final phone = ref.watch(signedInPhoneProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: phone.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            Center(child: Text('Account unavailable.', style: text.bodyMedium)),
        data: (number) => number == null
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.pageH),
                child: _SignedOut(text: text),
              )
            : _SignedIn(phone: number),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.text});

  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "You're not signed in.",
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sign in with your Robi or Airtel number to save your progress.',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => context.push(Routes.signIn),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.sm,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      children: [
        _Identity(phone: phone),

        const SizedBox(height: AppSpacing.xl),
        const _Label('Subscription'),
        const SizedBox(height: AppSpacing.sm),
        const _SubscriptionCard(),

        const SizedBox(height: AppSpacing.xl),
        const _Label('Your learning'),
        const SizedBox(height: AppSpacing.sm),
        _Row(
          icon: Icons.insights_outlined,
          title: 'See your progress',
          subtitle: 'Scores, before and after, every check you have taken',
          onTap: () => context.go(Routes.progress),
        ),

        const SizedBox(height: AppSpacing.xl),
        const _Label('About'),
        const SizedBox(height: AppSpacing.sm),
        const _VersionRow(),

        const SizedBox(height: AppSpacing.xl),
        const _Label('Account'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () async {
            // Only ends the session on this device. The subscription and the
            // daily charge are unaffected — unsubscribing is a separate act.
            await ref.read(sessionServiceProvider).signOut();
          },
          child: const Text('Sign out'),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _Footnote(
          'Only ends this session. Your subscription and your progress stay.',
        ),

        const SizedBox(height: AppSpacing.xl),
        _UnsubscribeButton(phone: phone),
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

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

// ---------------------------------------------------------------- identity

class _Identity extends ConsumerWidget {
  const _Identity({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    // Read on its own so a stamp that has not resolved yet leaves the rest of
    // the header intact rather than holding the whole screen.
    final since = ref.watch(memberSinceProvider).value;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phone.asPrettyPhone, style: text.headlineSmall),
                if (since != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Learning since ${_longDate(since)}',
                    style: text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ subscription

/// Price and state.
///
/// Watches [subscriptionProvider] here rather than at the top of the screen
/// so a bdapps call that fails takes down one card and not the account
/// screen — which is where someone goes when something is already wrong.
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final subscribed = ref.watch(subscriptionProvider);

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
              Expanded(child: Text('EngCoach', style: text.titleLarge)),
              subscribed.when(
                data: (active) => _StatePill(active: active),
                // No pill rather than a wrong one: "Active" shown while the
                // answer is unknown is worse than nothing on a screen about
                // money.
                loading: SizedBox.shrink,
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Tk 2.78', style: text.headlineMedium),
              const SizedBox(width: AppSpacing.sm),
              Text('per day', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // The STOP instruction used to appear here and again under the
            // unsubscribe button. Once is enough, and it belongs next to the
            // button that does the same thing.
            'Charged from your mobile balance. You can stop any time — the '
            'button is at the bottom of this screen.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = active
        ? AppStatusColors.completed
        : AppStatusColors.notStarted;

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
        active ? 'ACTIVE' : 'NOT ACTIVE',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.foreground),
      ),
    );
  }
}

// ------------------------------------------------------------------- about

class _VersionRow extends ConsumerWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final version = ref.watch(appVersionProvider).value;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: AppSpacing.md + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Version', style: text.bodyLarge)),
          // Blank until it resolves. A dash would read as "there is no
          // version", which is never true.
          Text(version ?? '', style: text.bodySmall),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- rows

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: Icon(icon, size: 18, color: AppColors.textOnMuted),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- unsubscribe

/// Ends the subscription, the charge and access — all at once.
///
/// Kept visually quiet and behind a confirmation: it costs money to undo
/// (resubscribing charges again) and takes effect immediately. But it must be
/// findable — someone who cannot cancel in the app will cancel by texting
/// 21213 and remember EngCoach as the thing that was hard to leave.
class _UnsubscribeButton extends ConsumerStatefulWidget {
  const _UnsubscribeButton({required this.phone});

  final String phone;

  @override
  ConsumerState<_UnsubscribeButton> createState() => _UnsubscribeButtonState();
}

class _UnsubscribeButtonState extends ConsumerState<_UnsubscribeButton> {
  bool _busy = false;
  String? _error;

  Future<void> _confirmAndUnsubscribe() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsubscribe from EngCoach?'),
        content: const Text(
          'The daily charge stops, and so does your access — straight away, '
          'not at the end of the day. Your progress is kept, so subscribing '
          'again picks up where you left off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).unsubscribe(widget.phone);
      // End the device session too, so the gate returns them to a clean
      // sign-in rather than a half-signed-in state with nothing to see.
      await ref.read(sessionServiceProvider).signOut();
      ref.invalidate(subscriptionProvider);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        TextButton(
          onPressed: _busy ? null : _confirmAndUnsubscribe,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Unsubscribe'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            style: text.bodySmall?.copyWith(color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        const _Footnote(
          'Stops the daily charge and your access. Your progress is kept, so '
          'subscribing again picks up where you left off. You can also send '
          'STOP engcoach to 21213.',
        ),
      ],
    );
  }
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "21 August 2026" — no intl dependency for one date.
String _longDate(DateTime at) =>
    '${at.day} ${_months[at.month - 1]} ${at.year}';
