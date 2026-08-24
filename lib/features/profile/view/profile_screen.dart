import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Account, subscription and data settings.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Temporary: the sign-in flow has no gate in front of it yet,
              // so this is how to reach it. Remove once auth guards startup.
              OutlinedButton(
                onPressed: () => context.push(Routes.signIn),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
