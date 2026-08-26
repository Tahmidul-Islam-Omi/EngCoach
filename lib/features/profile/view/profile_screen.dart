import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/repositories/session_repository.dart';

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
      ],
    );
  }
}
