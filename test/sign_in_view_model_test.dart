import 'package:engcoach/data/repositories/auth_repository.dart';
import 'package:engcoach/features/auth/model/sign_in_state.dart';
import 'package:engcoach/features/auth/viewmodel/sign_in_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers immediately and with a code the test chose, so nothing here
/// depends on timing or randomness.
class _StubAuth implements AuthRepository {
  _StubAuth({this.resendAfter = const Duration(seconds: 45)});

  static const code = '123456';
  final Duration resendAfter;
  int requests = 0;

  @override
  Future<CodeRequest> requestCode(String phone) async {
    requests++;
    return CodeRequest(resendAfter: resendAfter, debugCode: code);
  }

  @override
  Future<Session> verifyCode(String phone, String entered) async {
    if (entered != code) throw const AuthFailure('wrong');
    return Session(phone: phone);
  }
}

void main() {
  late _StubAuth auth;

  SignInViewModel modelIn(ProviderContainer c) =>
      c.read(signInViewModelProvider.notifier);
  SignInState stateIn(ProviderContainer c) => c.read(signInViewModelProvider);

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => auth = _StubAuth());

  group('phone entry', () {
    test('keeps digits only and stops at eleven', () {
      final c = makeContainer();
      modelIn(c).phoneChanged('017-12 345 6789999');
      expect(stateIn(c).phone, '01712345678');
    });

    test('is not sendable until eleven digits are in', () {
      final c = makeContainer();
      modelIn(c).phoneChanged('0171234');
      expect(stateIn(c).canSend, isFalse);
      modelIn(c).phoneChanged('01712345678');
      expect(stateIn(c).canSend, isTrue);
    });

    test('rejects a number that does not start with 01', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged('11712345678');
      await modelIn(c).sendCode();

      expect(stateIn(c).step, SignInStep.phone);
      expect(stateIn(c).error, contains('starting with 01'));
      expect(auth.requests, 0, reason: 'must not reach the repository');
    });

    test('typing again clears the error', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged('11712345678');
      await modelIn(c).sendCode();
      modelIn(c).phoneChanged('01712345678');

      expect(stateIn(c).error, isNull);
    });

    test('formats the number the way it is read back', () {
      final c = makeContainer();
      modelIn(c).phoneChanged('01712345678');
      expect(stateIn(c).prettyPhone, '+880 1712-345678');
    });
  });

  group('sending a code', () {
    Future<ProviderContainer> atCodeStep() async {
      final c = makeContainer();
      modelIn(c).phoneChanged('01712345678');
      await modelIn(c).sendCode();
      return c;
    }

    test('moves to the code step and starts the countdown', () async {
      final c = await atCodeStep();

      expect(stateIn(c).step, SignInStep.code);
      expect(stateIn(c).secondsLeft, 45);
      expect(stateIn(c).canResend, isFalse);
      expect(stateIn(c).busy, isFalse);
    });

    test('carries the debug code through for the dev banner', () async {
      final c = await atCodeStep();
      expect(stateIn(c).debugCode, '123456');
    });

    test('resend is refused while the countdown is running', () async {
      final c = await atCodeStep();
      await modelIn(c).resend();

      expect(auth.requests, 1, reason: 'a second code must not be requested');
    });

    test('a second tap while in flight does not ask twice', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged('01712345678');

      await Future.wait([modelIn(c).sendCode(), modelIn(c).sendCode()]);

      expect(auth.requests, 1);
    });

    test('the countdown actually ticks down', () async {
      auth = _StubAuth(resendAfter: const Duration(seconds: 1));
      final c = await atCodeStep();
      expect(stateIn(c).secondsLeft, 1);

      await Future<void>.delayed(const Duration(milliseconds: 1300));

      expect(stateIn(c).secondsLeft, 0);
      expect(stateIn(c).canResend, isTrue);
    });
  });

  group('verifying', () {
    Future<ProviderContainer> atCodeStep() async {
      final c = makeContainer();
      modelIn(c).phoneChanged('01712345678');
      await modelIn(c).sendCode();
      return c;
    }

    test('the right code signs the learner in', () async {
      final c = await atCodeStep();
      modelIn(c).codeChanged('123456');
      await modelIn(c).verify();

      expect(stateIn(c).step, SignInStep.done);
      expect(stateIn(c).error, isNull);
    });

    test('a wrong code clears the boxes but keeps the number', () async {
      final c = await atCodeStep();
      modelIn(c).codeChanged('000000');
      await modelIn(c).verify();

      expect(stateIn(c).step, SignInStep.code);
      expect(stateIn(c).code, isEmpty);
      expect(stateIn(c).phone, '01712345678');
      expect(stateIn(c).error, isNotNull);
    });

    test('an incomplete code never reaches the repository', () async {
      final c = await atCodeStep();
      modelIn(c).codeChanged('123');
      await modelIn(c).verify();

      expect(stateIn(c).step, SignInStep.code);
      expect(stateIn(c).error, isNull, reason: 'not an error, just not ready');
    });
  });

  group('changing the number', () {
    test('goes back with the number intact and the code cleared', () async {
      final c = makeContainer();
      modelIn(c).phoneChanged('01712345678');
      await modelIn(c).sendCode();
      modelIn(c).codeChanged('9999');
      modelIn(c).changeNumber();

      expect(stateIn(c).step, SignInStep.phone);
      expect(stateIn(c).phone, '01712345678');
      expect(stateIn(c).code, isEmpty);
      expect(stateIn(c).debugCode, isNull);
    });
  });
}
