import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A signed-in learner.
///
/// The phone number IS the identity — there is no separate user id. bdapps
/// supplies the one-time code, and everything user-scoped keys on the
/// number, so no account linking is needed when real auth replaces the fake.
class Session {
  const Session({required this.phone});

  final String phone;
}

/// What asking for a code tells the app.
///
/// [debugCode] is the seam that lets the whole sign-in flow be built and
/// tested before any SMS exists: the fake implementation hands the code
/// straight back and the screen shows it. The real one leaves it null,
/// because by then bdapps is doing the delivering.
class CodeRequest {
  const CodeRequest({required this.resendAfter, this.debugCode});

  /// How long before the learner may ask for another code.
  final Duration resendAfter;

  final String? debugCode;
}

/// A code was rejected. Carries wording the screen can show as-is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sends and checks one-time codes.
///
/// Implementations differ only in how the code travels. Nothing above this
/// interface changes when the Cloud Function and bdapps replace the fake —
/// the same swap point that [ContentRepository] uses for Firestore.
abstract interface class AuthRepository {
  Future<CodeRequest> requestCode(String phone);

  /// Exchanges a code for a session, or throws [AuthFailure].
  Future<Session> verifyCode(String phone, String code);
}

/// Generates and checks codes on the device.
///
/// Everything except delivery is real: generation, the wrong-code path, the
/// resend window. So swapping in the Cloud Function changes how the code
/// reaches the learner, not what the screen does with it.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    Random? random,
    this.latency = const Duration(milliseconds: 600),
    this.resendAfter = const Duration(seconds: 45),
  }) : _random = random ?? Random();

  final Random _random;

  /// Stands in for a round trip, so the screen's busy state is exercised.
  final Duration latency;

  final Duration resendAfter;

  String? _issued;

  @override
  Future<CodeRequest> requestCode(String phone) async {
    await Future<void>.delayed(latency);
    _issued = (_random.nextInt(900000) + 100000).toString();
    return CodeRequest(
      resendAfter: resendAfter,
      // Never hand a code to the UI outside a debug build, even from here.
      debugCode: kDebugMode ? _issued : null,
    );
  }

  @override
  Future<Session> verifyCode(String phone, String code) async {
    await Future<void>.delayed(latency);
    if (_issued == null || code != _issued) {
      throw const AuthFailure(
        'That code is not right. Check the digits and try again.',
      );
    }
    return Session(phone: phone);
  }
}

/// The one line that changes when the Cloud Function lands.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(),
);
