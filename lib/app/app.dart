import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'startup.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class EngCoachApp extends ConsumerWidget {
  const EngCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Creates the user document and stamps the visit whenever a session
    // exists — at sign-in, and again on every launch once Firebase restores
    // the stored one. Watched here only to keep it alive.
    ref.watch(visitStampProvider);

    return MaterialApp.router(
      title: 'EngCoach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
