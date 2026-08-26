import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/subscription_provider.dart';

/// Account and subscription.
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
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageH),
        child: phone.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text('Account unavailable.', style: text.bodyMedium),
          ),
          data: (number) => number == null
              ? _SignedOut(text: text)
              : _SignedIn(phone: number, text: text),
        ),
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
  const _SignedIn({required this.phone, required this.text});

  final String phone;
  final TextTheme text;

  /// "+880 1895-613473" — how a Bangladeshi number is normally read back.
  String get _pretty => phone.length == 11
      ? '+880 ${phone.substring(1, 5)}-${phone.substring(5)}'
      : phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIGNED IN AS', style: text.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(_pretty, style: text.headlineSmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SUBSCRIPTION', style: text.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                Text('Tk 2.78 per day', style: text.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Charged from your mobile balance. To stop, send '
                  'STOP engcoach to 21213.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton(
          onPressed: () async {
            // Only ends the session on this device. The subscription and the
            // daily charge are unaffected — unsubscribing is a separate act.
            await ref.read(sessionRepositoryProvider).signOut();
          },
          child: const Text('Sign out'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Signing out does not unsubscribe you.',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),
        _UnsubscribeButton(phone: phone, text: text),
      ],
    );
  }
}

/// Ends the subscription, the charge and access — all at once.
///
/// Kept visually quiet and behind a confirmation: it costs money to undo
/// (resubscribing charges again) and takes effect immediately. But it must be
/// findable — someone who cannot cancel in the app will cancel by texting
/// 21213 and remember EngCoach as the thing that was hard to leave.
class _UnsubscribeButton extends ConsumerStatefulWidget {
  const _UnsubscribeButton({required this.phone, required this.text});

  final String phone;
  final TextTheme text;

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
      await ref.read(authRepositoryProvider).unsubscribe(widget.phone);
      // Re-reads bdapps, which sends them through the gate to the
      // subscription-ended screen. No navigation needed here.
      ref.invalidate(subscriptionProvider);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            style: widget.text.bodySmall?.copyWith(color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'You can also unsubscribe any time by sending '
          'STOP engcoach to 21213.',
          style: widget.text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
