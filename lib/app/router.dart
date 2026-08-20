import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/grammar/view/grammar_topics_screen.dart';
import '../features/grammar/view/topic_overview_screen.dart';
import '../features/home/view/home_screen.dart';
import '../features/learn/view/learn_screen.dart';
import '../features/profile/view/profile_screen.dart';
import '../features/progress/view/progress_screen.dart';
import '../shared/widgets/app_shell.dart';

/// Route paths. Referenced by name so a typo is a compile error, not a
/// runtime 404.
abstract final class Routes {
  static const home = '/';
  static const learn = '/learn';
  static const grammar = '/learn/grammar';
  static const progress = '/progress';
  static const profile = '/profile';
}

final _rootKey = GlobalKey<NavigatorState>();

/// A provider rather than a plain global so that, once auth exists, the
/// router can watch auth state and redirect without restructuring.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    routes: [
      // Keeps one Navigator per tab, so each tab remembers where it was.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, _) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.learn,
              builder: (_, _) => const LearnScreen(),
              routes: [
                GoRoute(
                  path: 'grammar',
                  builder: (_, _) => const GrammarTopicsScreen(),
                  routes: [
                    GoRoute(
                      path: ':topicId',
                      builder: (_, state) => TopicOverviewScreen(
                        topicId: state.pathParameters['topicId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.progress,
              builder: (_, _) => const ProgressScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.profile,
              builder: (_, _) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
