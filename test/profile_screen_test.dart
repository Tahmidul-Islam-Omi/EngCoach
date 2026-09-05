import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/core/extensions/phone_format.dart';
import 'package:engcoach/data/repositories/progress_repository.dart';
import 'package:engcoach/data/services/auth_service.dart';
import 'package:engcoach/data/services/session_service.dart';
import 'package:engcoach/features/profile/view/profile_screen.dart';
import 'package:engcoach/features/profile/viewmodel/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const phone = '8801895613473';

  late GoRouter router;
  String opened() => router.state.uri.toString();

  Future<void> pumpProfile(
    WidgetTester tester, {
    String? signedInAs = phone,
    bool? subscribed = true,
    DateTime? memberSince,
    String version = '1.0.0 (1)',
  }) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    router = GoRouter(
      initialLocation: Routes.profile,
      routes: [
        GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: Routes.progress,
          builder: (_, _) => const Scaffold(body: Text('opened progress')),
        ),
        GoRoute(
          path: Routes.signIn,
          builder: (_, _) => const Scaffold(body: Text('opened sign-in')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInPhoneProvider.overrideWith((_) => Stream.value(signedInAs)),
          subscriptionProvider.overrideWith(
            (_) async => subscribed ?? (throw const AuthFailure('offline')),
          ),
          memberSinceProvider.overrideWith((_) async => memberSince),
          appVersionProvider.overrideWith((_) async => version),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header is the learner, and says how long they have been '
      'here', (tester) async {
    await pumpProfile(tester, memberSince: DateTime(2026, 8, 21));

    expect(find.text(phone.asPrettyPhone), findsOneWidget);
    expect(find.text('Learning since 21 August 2026'), findsOneWidget);
  });

  testWidgets('an unresolved stamp leaves the header intact', (tester) async {
    // createdAt is a server timestamp, so it reads back null until it
    // resolves — and on the very first launch there is nothing to read.
    await pumpProfile(tester, memberSince: null);

    expect(find.text(phone.asPrettyPhone), findsOneWidget);
    expect(find.textContaining('Learning since'), findsNothing);
  });

  testWidgets('the subscription card shows the state it already asks for', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Tk 2.78'), findsOneWidget);
    expect(find.text('per day'), findsOneWidget);
  });

  testWidgets('the STOP instruction appears once, by the button that does it', (
    tester,
  ) async {
    await pumpProfile(tester);

    // It used to be in the subscription card and again in the footnote.
    expect(find.textContaining('STOP engcoach to 21213'), findsOneWidget);
    expect(
      find.textContaining('You can also send STOP engcoach to 21213'),
      findsOneWidget,
    );
  });

  testWidgets('a failed subscription check costs one card, not the screen', (
    tester,
  ) async {
    await pumpProfile(tester, subscribed: null);

    // No pill rather than a wrong one — but everything else still renders.
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('NOT ACTIVE'), findsNothing);
    expect(find.text(phone.asPrettyPhone), findsOneWidget);
    expect(find.text('Tk 2.78'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('the version is on screen, for when someone reports a problem', (
    tester,
  ) async {
    await pumpProfile(tester, version: '2.3.1 (47)');

    expect(find.text('Version'), findsOneWidget);
    expect(find.text('2.3.1 (47)'), findsOneWidget);
  });

  testWidgets('progress is one row away, not copied here', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('See your progress'));
    await tester.pumpAndSettle();
    expect(opened(), Routes.progress);
  });

  testWidgets('signed out offers a way in', (tester) async {
    await pumpProfile(tester, signedInAs: null);

    expect(find.text("You're not signed in."), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(opened(), Routes.signIn);
  });
}
