import 'package:engcoach/data/repositories/auth_repository.dart';
import 'package:engcoach/data/repositories/session_repository.dart';
import 'package:engcoach/features/auth/model/sign_in_state.dart';
import 'package:engcoach/features/auth/viewmodel/sign_in_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers immediately, so nothing here depends on timing or the network.
class _StubAuth implements AuthRepository {
  _StubAuth({this.resendAfter = const Duration(seconds: 45)});

  static const code = '123456';
  static const reference = 'ref-8801895613473';

  /// When true, [start] signs the learner in with no code — the real
  /// behaviour for a number bdapps already has as REGISTERED.
  bool subscribed = false;

  final Duration resendAfter;

  /// Set to make [start] throw, standing in for a dead network.
  String? failStartWith;

  int starts = 0;
  int verifies = 0;

  @override
  Future<SignInStart> start(String phone) async {
    starts++;
    final failure = failStartWith;
    if (failure != null) throw AuthFailure(failure);

    if (subscribed) {
      return AlreadySignedIn(
        Session(phone: phone, isSubscribed: true, firebaseToken: 'token'),
      );
    }
    return CodeSent(referenceNo: reference, resendAfter: resendAfter);
  }

  @override
  Future<Session> verify({
    required String phone,
    required String code,
    required String referenceNo,
  }) async {
    verifies++;
    if (code != _StubAuth.code) {
      throw const AuthFailure('That code is not right.');
    }
    return Session(phone: phone, isSubscribed: true, firebaseToken: 'token');
  }

  @override
  Future<bool> isSubscribed(String phone) async => subscribed;

  @override
  Future<void> unsubscribe(String phone) async => subscribed = false;
}

/// Stands in for Firebase Auth, which needs a real plugin and a device.
class _StubSession implements SessionRepository {
  String? phone;
  bool failSignIn = false;

  @override
  String? get currentPhone => phone;

  @override
  Stream<String?> phoneChanges() => Stream.value(phone);

  @override
  Future<void> signIn(Session session) async {
    if (failSignIn || session.firebaseToken == null) {
      throw const AuthFailure("Signed in, but your progress can't be saved yet.");
    }
    phone = session.phone;
  }

  @override
  Future<void> signOut() async => phone = null;
}

void main() {
  const phone = '01895613473';

  late _StubAuth auth;
  late _StubSession session;

  SignInViewModel modelIn(ProviderContainer c) =>
      c.read(signInViewModelProvider.notifier);
  SignInState stateIn(ProviderContainer c) => c.read(signInViewModelProvider);

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionRepositoryProvider.overrideWithValue(session),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    auth = _StubAuth();
    session = _StubSession();
  });

  group('phone entry', () {
    test('keeps digits only and stops at eleven', () {
      final c = makeContainer();
      modelIn(c).phoneChanged('018-95 613 4739999');
      expect(stateIn(c).phone, '01895613473');
    });

    test('is not sendable until eleven digits are in', () {
      final c = makeContainer();
      modelIn(c).phoneChanged('0189561');
      expect(stateIn(c).canSend, isFalse);
      modelIn(c).phoneChanged(phone);
      expect(stateIn(c).canSend, isTrue);
    });

    test('rejects a carrier bdapps does not serve', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged('01712345678');
      await modelIn(c).sendCode();

      expect(stateIn(c).error, contains('Robi and Airtel'));
      expect(auth.starts, 0, reason: 'answered without a round trip');
    });

    test('accepts both Robi and Airtel prefixes', () async {
      for (final number in ['01812345678', '01612345678']) {
        auth = _StubAuth();
        session = _StubSession();
        final c = makeContainer();
        modelIn(c).phoneChanged(number);
        await modelIn(c).sendCode();

        expect(stateIn(c).error, isNull, reason: number);
        expect(stateIn(c).step, SignInStep.code, reason: number);
      }
    });

    test('rejects a number that does not start with 01', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged('11895613473');
      await modelIn(c).sendCode();

      expect(stateIn(c).error, contains('starting with 01'));
      expect(auth.starts, 0, reason: 'never reaches the network');
    });
  });

  group('a new number', () {
    test('is sent a code and moves to the code step', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();

      final state = stateIn(c);
      expect(state.step, SignInStep.code);
      expect(state.referenceNo, _StubAuth.reference);
      expect(state.secondsLeft, 45);
      expect(state.busy, isFalse);
    });

    test('the right code signs them in and opens a Firebase session',
        () async {
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();
      modelIn(c).codeChanged(_StubAuth.code);
      await modelIn(c).verify();

      final state = stateIn(c);
      expect(state.step, SignInStep.done);
      expect(state.session?.isSubscribed, isTrue);
      expect(session.currentPhone, phone, reason: 'token was exchanged');
      expect(state.syncUnavailable, isFalse);
    });

    test('a failed token exchange still leaves them signed in', () async {
      // bdapps verified them and, on this path, already charged them. Sending
      // them back to the phone screen would be wrong.
      session.failSignIn = true;
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();
      modelIn(c).codeChanged(_StubAuth.code);
      await modelIn(c).verify();

      final state = stateIn(c);
      expect(state.step, SignInStep.done);
      expect(state.error, contains("can't be saved"));
      expect(session.currentPhone, isNull);
    });

    test('a wrong code keeps the reference, so no second SMS is needed',
        () async {
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();
      modelIn(c).codeChanged('000000');
      await modelIn(c).verify();

      final state = stateIn(c);
      expect(state.step, SignInStep.code);
      expect(state.code, isEmpty, reason: 'boxes cleared to retype');
      expect(state.phone, phone, reason: 'the number is kept');
      expect(state.referenceNo, _StubAuth.reference);
      expect(state.error, isNotNull);
      expect(auth.starts, 1, reason: 'the retry costs no new code');
    });

    test('verifying without a reference never reaches the network', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      modelIn(c).codeChanged(_StubAuth.code);
      await modelIn(c).verify();

      expect(auth.verifies, 0);
      expect(stateIn(c).step, SignInStep.phone);
    });
  });

  group('a number that is already subscribed', () {
    test('is signed in without ever seeing a code', () async {
      auth.subscribed = true;
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();

      final state = stateIn(c);
      expect(state.step, SignInStep.done);
      expect(state.referenceNo, isNull);
      expect(state.signedInWithoutCode, isTrue);
      expect(state.session?.isSubscribed, isTrue);
      expect(session.currentPhone, phone);
      expect(auth.verifies, 0);
    });

    test('runs no countdown, because there is nothing to resend', () async {
      auth.subscribed = true;
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();

      expect(stateIn(c).secondsLeft, 0);
    });
  });

  group('resending', () {
    test('asks again and restarts the countdown', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();

      // The countdown must be clear before a resend is allowed.
      modelIn(c).codeChanged('12');
      await modelIn(c).resend();
      expect(auth.starts, 1, reason: 'blocked while the countdown runs');
    });

    test('signs them in if they subscribed by SMS while the screen was open',
        () async {
      // No resend lock, so the second call is allowed straight away.
      auth = _StubAuth(resendAfter: Duration.zero);
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();

      // Someone texting "engcoach" to 21213 mid-flow becomes REGISTERED, and
      // bdapps would then refuse another code.
      auth.subscribed = true;
      await modelIn(c).resend();

      expect(stateIn(c).step, SignInStep.done);
      expect(auth.starts, 2);
    });

    test('a resend after the lock clears asks for a new code', () async {
      auth = _StubAuth(resendAfter: Duration.zero);
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();
      modelIn(c).codeChanged('12');

      await modelIn(c).resend();

      expect(auth.starts, 2);
      expect(stateIn(c).code, isEmpty, reason: 'the old code is cleared');
    });
  });

  group('failures', () {
    test('a network failure shows wording and stays put', () async {
      auth.failStartWith = "Couldn't reach the network.";
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();

      final state = stateIn(c);
      expect(state.step, SignInStep.phone);
      expect(state.error, contains('network'));
      expect(state.busy, isFalse);
    });
  });

  group('changing the number', () {
    test('goes back with the number kept and the code cleared', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged(phone);
      await modelIn(c).sendCode();
      modelIn(c).codeChanged('123');

      modelIn(c).changeNumber();

      final state = stateIn(c);
      expect(state.step, SignInStep.phone);
      expect(state.phone, phone);
      expect(state.code, isEmpty);
      expect(state.referenceNo, isNull);
    });
  });
}
