import 'dart:async';

import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/data/models/topic.dart';
import 'package:engcoach/data/repositories/auth_repository.dart';
import 'package:engcoach/data/repositories/content_repository.dart';
import 'package:engcoach/data/repositories/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/topic_fixture.dart';

/// Emits sessions on demand, standing in for Firebase Auth.
class _StubSession implements SessionRepository {
  final _controller = StreamController<String?>.broadcast();
  String? phone;

  void emit(String? value) {
    phone = value;
    _controller.add(value);
  }

  @override
  String? get currentPhone => phone;

  @override
  Stream<String?> phoneChanges() => _controller.stream;

  @override
  Future<void> signIn(Session session) async => emit(session.phone);

  @override
  Future<void> signOut() async => emit(null);

  void dispose() => _controller.close();
}

class _StubAuth implements AuthRepository {
  bool subscribed = true;
  bool failCheck = false;

  @override
  Future<bool> isSubscribed(String phone) async {
    if (failCheck) throw const AuthFailure('offline');
    return subscribed;
  }

  @override
  Future<SignInStart> start(String phone) async =>
      throw UnimplementedError();

  @override
  Future<void> unsubscribe(String phone) async => subscribed = false;

  @override
  Future<Session> verify({
    required String phone,
    required String code,
    required String referenceNo,
  }) async =>
      throw UnimplementedError();
}

class _StubContent implements ContentRepository {
  @override
  Future<Topic> topicById(String id) async => buildTopic();

  @override
  Future<List<Topic>> topicsForSection(String section) async => [buildTopic()];
}

void main() {
  late _StubSession session;
  late _StubAuth auth;

  setUp(() {
    session = _StubSession();
    auth = _StubAuth();
  });

  tearDown(() => session.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(session),
        authRepositoryProvider.overrideWithValue(auth),
        contentRepositoryProvider.overrideWithValue(_StubContent()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(routerProvider),
            theme: AppTheme.light,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('holds on the splash while the session is restoring',
      (tester) async {
    await pumpApp(tester);

    // Nothing emitted yet: the stored session has not resolved.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('sends a signed-out learner to sign-in', (tester) async {
    await pumpApp(tester);

    session.emit(null);
    await tester.pumpAndSettle();

    expect(find.textContaining('English that finally'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lets a subscribed learner through to the app', (tester) async {
    auth.subscribed = true;
    await pumpApp(tester);

    session.emit('01895613473');
    await tester.pumpAndSettle();

    // The tab shell only exists past the gate.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('sends a signed-in learner who stopped paying back to sign-in',
      (tester) async {
    auth.subscribed = false;
    await pumpApp(tester);

    session.emit('01895613473');
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    // Sign-in doubles as the subscribe flow, so it is where a lapsed
    // subscriber belongs — not on a dead-end notice. Asserted on the hero
    // because the form sits below the fold of a long landing page.
    expect(find.textContaining('English that finally'), findsOneWidget);
  });

  testWidgets('a failed subscription check offers a retry, not a spinner',
      (tester) async {
    // A learner on bad mobile data must never be stranded on the splash.
    auth.failCheck = true;
    await pumpApp(tester);

    session.emit('01895613473');
    await tester.pumpAndSettle();

    // Never stranded on a spinner: they land somewhere they can act.
    expect(find.textContaining('English that finally'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a re-check does not throw a learner out of the app',
      (tester) async {
    // Re-fetching arrives as loading-with-a-previous-value. Treating that as
    // "unknown" would bounce them to the splash mid-task.
    auth.subscribed = true;
    await pumpApp(tester);
    session.emit('01895613473');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    session.emit('01895613473');
    await tester.pump();

    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'still in the app while the check refreshes',
    );
  });

  testWidgets('sign-in never opens showing a previous visit',
      (tester) async {
    // Unsubscribing sends someone back here, and the view model outlives the
    // screen — so a stale "done" would leave them staring at a spinner.
    auth.subscribed = true;
    await pumpApp(tester);
    session.emit('01895613473');
    await tester.pumpAndSettle();

    auth.subscribed = false;
    session.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('Signing you in…'), findsNothing);
    expect(find.textContaining('English that finally'), findsOneWidget);
  });

  testWidgets('signing out from inside the app returns to sign-in',
      (tester) async {
    auth.subscribed = true;
    await pumpApp(tester);
    session.emit('01895613473');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    session.emit(null);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
  });
}
