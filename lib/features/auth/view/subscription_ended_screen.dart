import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/subscription_provider.dart';

/// Shown when a signed-in learner is no longer being charged.
///
/// Reachable by unsubscribing outside the app — texting STOP engcoach to
/// 21213, or the USSD menu — so it has to explain something the learner may
/// not remember doing.
class SubscriptionEndedScreen extends ConsumerWidget {
  const SubscriptionEndedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    // This screen is also where a failed subscription check lands, because
    // stranding someone on a spinner is worse than asking them to retry. But
    // it must not tell a learner their subscription stopped when the real
    // problem was their connection.
    final unreachable = ref.watch(subscriptionProvider).hasError;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.warningSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unreachable ? Icons.wifi_off_rounded : Icons.pause_rounded,
                  size: 30,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                unreachable
                    ? "We couldn't check your subscription."
                    : 'Your subscription has stopped.',
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                unreachable
                    ? 'Check your connection and try again. Nothing has '
                        'changed on your account.'
                    : 'EngCoach is Tk 2.78 per day, charged from your mobile '
                        'balance. Subscribe again to pick up where you left '
                        'off — your progress is still here.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (unreachable)
                FilledButton(
                  onPressed: () => ref.invalidate(subscriptionProvider),
                  child: const Text('Try again'),
                )
              else ...[
                FilledButton(
                  // Sign-in doubles as the subscribe flow: the number is
                  // UNREGISTERED now, so bdapps will issue an OTP for it.
                  onPressed: () => context.go(Routes.signIn),
                  child: const Text('Subscribe again'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => ref.invalidate(subscriptionProvider),
                  child: const Text('I already subscribed — check again'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () =>
                    ref.read(sessionRepositoryProvider).signOut(),
                child: const Text('Use a different number'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
