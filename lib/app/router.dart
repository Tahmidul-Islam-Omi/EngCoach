import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/session_repository.dart';
import '../data/repositories/subscription_provider.dart';
import '../features/assessment/view/pre_assessment_screen.dart';
import '../features/auth/view/sign_in_screen.dart';
import '../features/auth/view/starting_screen.dart';
import '../features/auth/view/subscription_ended_screen.dart';
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

  /// The focused topic flow — assessment, lessons, practice, results.
  ///
  /// Deliberately OUTSIDE the tab shell: once a learner starts a topic the
  /// bottom nav would invite them to wander mid-assessment. These screens
  /// offer an explicit exit instead.
  static String topic(String id) => '/topic/$id';

  /// The topic's pre-assessment. Nested under the topic, so leaving it
  /// lands back on the overview rather than the tab it was reached from.
  static String preAssessment(String id) => '/topic/$id/check';

  static const progress = '/progress';
  static const profile = '/profile';

  /// Sign-in. Outside the shell for the same reason the topic flow is: the
  /// tab bar has nothing to offer someone who isn't signed in yet.
  static const signIn = '/sign-in';

  /// Shown while the stored session is being restored, so a returning learner
  /// never sees sign-in flash past on launch.
  static const starting = '/starting';

  /// Signed in, but no longer being charged — usually because they texted
  /// STOP engcoach to 21213.
  static const subscriptionEnded = '/subscription-ended';
}

/// Where the router may send someone who is not yet past the gate.
const _outsideTheGate = {
  Routes.starting,
  Routes.signIn,
  Routes.subscriptionEnded,
};

final _rootKey = GlobalKey<NavigatorState>();

/// A provider so the gate can watch auth and subscription state.
///
/// EngCoach is subscription-only: nothing is readable without a paid,
/// signed-in number. Both checks live here rather than in each screen, so
/// there is one place to be wrong about.
final routerProvider = Provider<GoRouter>((ref) {
  // GoRouter is built once; a ValueNotifier is how it hears about changes.
  // Watching providers in this builder would rebuild the router itself and
  // throw away the navigation stack.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(signedInPhoneProvider, (_, _) => refresh.value++);
  ref.listen(subscriptionProvider, (_, _) => refresh.value++);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.starting,
    refreshListenable: refresh,
    redirect: (context, state) {
      final here = state.matchedLocation;

      final phoneState = ref.read(signedInPhoneProvider);

      // `value` rather than a type check, so a re-fetch — which arrives as
      // AsyncLoading carrying the previous value — does not bounce a learner
      // out of whatever they were doing.
      final phone = phoneState.value;

      if (phone == null) {
        // No value yet and no error: the stored session is still being
        // restored. Hold on the splash rather than flashing sign-in at
        // someone who is in fact signed in.
        if (!phoneState.hasError && phoneState.isLoading) {
          return here == Routes.starting ? null : Routes.starting;
        }
        return here == Routes.signIn ? null : Routes.signIn;
      }

      final subscriptionState = ref.read(subscriptionProvider);
      final subscribed = subscriptionState.value;

      if (subscribed == null && subscriptionState.isLoading) {
        return here == Routes.starting ? null : Routes.starting;
      }

      // Not subscribed, or the check failed with nothing cached to fall back
      // on. Both land on the same screen, which offers a retry — a learner
      // whose connection dropped must never be stranded on a spinner.
      if (subscribed != true) {
        // Sign-in is still reachable: it doubles as the resubscribe flow.
        return here == Routes.subscriptionEnded || here == Routes.signIn
            ? null
            : Routes.subscriptionEnded;
      }

      // Past the gate. The three gate routes have nothing left to say.
      return _outsideTheGate.contains(here) ? Routes.home : null;
    },
    routes: [
      GoRoute(
        path: Routes.starting,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const StartingScreen(),
      ),

      GoRoute(
        path: Routes.subscriptionEnded,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SubscriptionEndedScreen(),
      ),

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

      GoRoute(
        path: Routes.signIn,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SignInScreen(),
      ),

      // Sits alongside the shell rather than inside it — no tab bar.
      GoRoute(
        path: '/topic/:topicId',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => TopicOverviewScreen(
          topicId: state.pathParameters['topicId']!,
        ),
        routes: [
          GoRoute(
            path: 'check',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => PreAssessmentScreen(
              topicId: state.pathParameters['topicId']!,
            ),
          ),
        ],
      ),
    ],
  );
});
