import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// Shown while the stored Firebase session is being restored.
///
/// Without it, a returning learner sees the sign-in screen flash before the
/// session resolves — which reads as "I've been signed out" every launch.
class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/brand/logo_mark.png',
            width: 72,
            height: 72,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    ),
  );
}
