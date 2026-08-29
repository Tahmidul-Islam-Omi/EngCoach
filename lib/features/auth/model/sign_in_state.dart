import 'package:flutter/foundation.dart';

import '../../../core/extensions/phone_format.dart';
import '../../../data/repositories/auth_repository.dart';

/// Where the learner is in the sign-in flow.
///
/// [code] is skipped entirely for a number that is already subscribed:
/// bdapps refuses to issue a subscription OTP to an existing subscriber, so
/// there is no code to ask for.
enum SignInStep { phone, code, done }

/// Everything the sign-in screen draws from.
///
/// Immutable, so a rebuild can only come from the view model assigning new
/// state — never from a widget mutating a field behind its back.
@immutable
class SignInState {
  const SignInState({
    this.step = SignInStep.phone,
    this.phone = '',
    this.code = '',
    this.secondsLeft = 0,
    this.error,
    this.referenceNo,
    this.session,
    this.busy = false,
  });

  final SignInStep step;

  /// Digits only, never formatted. Formatting is a display concern.
  final String phone;

  /// Digits only, up to [codeLength].
  final String code;

  /// Countdown until another code may be requested.
  final int secondsLeft;

  /// Wording to show under the field, already learner-facing.
  final String? error;

  /// bdapps' handle on the code it sent. Must go back with the code, and
  /// survives a wrong attempt — so a mistyped code costs no second SMS.
  final String? referenceNo;

  /// Set once sign-in succeeds, by either route.
  final Session? session;

  /// Signed in with bdapps, but Firestore is out of reach — the server could
  /// not mint a token. Worth showing: progress will not be saved.
  bool get syncUnavailable =>
      step == SignInStep.done && session?.firebaseToken == null;

  /// A request is in flight; the buttons should not fire twice.
  final bool busy;

  static const phoneLength = 11;
  static const codeLength = 6;

  /// Robi (018) and Airtel (016). bdapps rejects every other carrier with
  /// E1325 — checked here only so the learner hears why immediately, rather
  /// than after a round trip that answers "Format of the address is invalid".
  static const carrierPrefixes = {'016', '018'};

  bool get phoneComplete => phone.length == phoneLength;

  bool get carrierSupported =>
      phone.length >= 3 && carrierPrefixes.contains(phone.substring(0, 3));
  bool get codeComplete => code.length == codeLength;
  bool get canResend => secondsLeft == 0;

  bool get canSend => phoneComplete && !busy;
  bool get canVerify => codeComplete && !busy && referenceNo != null;

  /// True when the learner reached the end without ever seeing a code —
  /// they were already subscribed.
  bool get signedInWithoutCode =>
      step == SignInStep.done && referenceNo == null;

  /// How the number is read back, or a placeholder while it is incomplete.
  String get prettyPhone => phoneComplete ? phone.asPrettyPhone : '+880 …';

  /// "0:45", for the resend countdown.
  String get clock {
    final m = secondsLeft ~/ 60;
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Distinguishes "leave this field alone" from "set it to null", which a
  /// plain nullable parameter cannot do.
  static const _keep = Object();

  SignInState copyWith({
    SignInStep? step,
    String? phone,
    String? code,
    int? secondsLeft,
    Object? error = _keep,
    Object? referenceNo = _keep,
    Object? session = _keep,
    bool? busy,
  }) {
    return SignInState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      code: code ?? this.code,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      error: identical(error, _keep) ? this.error : error as String?,
      referenceNo: identical(referenceNo, _keep)
          ? this.referenceNo
          : referenceNo as String?,
      session: identical(session, _keep) ? this.session : session as Session?,
      busy: busy ?? this.busy,
    );
  }
}
