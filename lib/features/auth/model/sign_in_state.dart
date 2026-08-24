import 'package:flutter/foundation.dart';

/// Where the learner is in the sign-in flow.
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
    this.debugCode,
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

  /// Only ever set in debug builds, by the fake repository.
  final String? debugCode;

  /// A request is in flight; the buttons should not fire twice.
  final bool busy;

  static const phoneLength = 11;
  static const codeLength = 6;

  bool get phoneComplete => phone.length == phoneLength;
  bool get codeComplete => code.length == codeLength;
  bool get canResend => secondsLeft == 0;

  bool get canSend => phoneComplete && !busy;
  bool get canVerify => codeComplete && !busy;

  /// "+880 1712-345678" — how a Bangladeshi number is normally read back.
  String get prettyPhone => phoneComplete
      ? '+880 ${phone.substring(1, 5)}-${phone.substring(5)}'
      : '+880 …';

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
    Object? debugCode = _keep,
    bool? busy,
  }) {
    return SignInState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      code: code ?? this.code,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      error: identical(error, _keep) ? this.error : error as String?,
      debugCode:
          identical(debugCode, _keep) ? this.debugCode : debugCode as String?,
      busy: busy ?? this.busy,
    );
  }
}
