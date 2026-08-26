import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';
import '../model/sign_in_state.dart';

/// Drives the sign-in flow.
///
/// The app's first view model, and the pattern the rest follow: the widget
/// holds no logic and no state of its own, it reads [SignInState] and calls
/// methods here. Everything below is testable with no widgets and no device.
class SignInViewModel extends Notifier<SignInState> {
  Timer? _ticker;

  @override
  SignInState build() {
    ref.onDispose(_stopCountdown);
    return const SignInState();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Keeps digits only — the field's formatters do the same, but the view
  /// model cannot assume a particular widget is in front of it.
  void phoneChanged(String value) {
    final digits = _digits(value, SignInState.phoneLength);
    state = state.copyWith(phone: digits, error: null);
  }

  void codeChanged(String value) {
    final digits = _digits(value, SignInState.codeLength);
    state = state.copyWith(code: digits, error: null);
  }

  Future<void> sendCode() async {
    if (state.busy) return;

    // Checked here rather than only on the button's enabled state, so the
    // rule holds however the method is reached.
    if (!state.phoneComplete || !state.phone.startsWith('01')) {
      state = state.copyWith(
        error: 'Enter an 11-digit number starting with 01.',
      );
      return;
    }

    state = state.copyWith(busy: true, error: null);
    try {
      switch (await _auth.start(state.phone)) {
        // Already subscribed: bdapps will not issue a code, so there is
        // nothing to ask for and the learner is straight in.
        case AlreadySignedIn(:final session):
          _stopCountdown();
          state = state.copyWith(
            step: SignInStep.done,
            busy: false,
            error: null,
            session: session,
          );

        case CodeSent(:final referenceNo, :final resendAfter):
          state = state.copyWith(
            step: SignInStep.code,
            busy: false,
            code: '',
            error: null,
            referenceNo: referenceNo,
          );
          _startCountdown(resendAfter);
      }
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  /// Finishes the new-subscriber flow. This is the call that subscribes the
  /// learner and starts the daily charge.
  Future<void> verify() async {
    final referenceNo = state.referenceNo;
    if (state.busy || !state.codeComplete || referenceNo == null) return;

    state = state.copyWith(busy: true, error: null);
    try {
      final session = await _auth.verify(
        phone: state.phone,
        code: state.code,
        referenceNo: referenceNo,
      );
      _stopCountdown();
      state = state.copyWith(
        step: SignInStep.done,
        busy: false,
        session: session,
      );
    } on AuthFailure catch (e) {
      // Clear the boxes but keep the number and the reference: a wrong code
      // does not invalidate the reference, so retrying costs no second SMS.
      state = state.copyWith(busy: false, code: '', error: e.message);
    }
  }

  Future<void> resend() async {
    if (state.busy || !state.canResend) return;

    state = state.copyWith(busy: true, error: null);
    try {
      // Deliberately the same call as the first attempt: it re-reads the
      // subscription, so someone who subscribed by texting 21213 while this
      // screen was open is signed in rather than sent a code that cannot come.
      switch (await _auth.start(state.phone)) {
        case AlreadySignedIn(:final session):
          _stopCountdown();
          state = state.copyWith(
            step: SignInStep.done,
            busy: false,
            session: session,
          );

        case CodeSent(:final referenceNo, :final resendAfter):
          state = state.copyWith(
            busy: false,
            code: '',
            referenceNo: referenceNo,
          );
          _startCountdown(resendAfter);
      }
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  /// Back to the number, keeping it so a typo is corrected rather than
  /// retyped.
  void changeNumber() {
    _stopCountdown();
    state = state.copyWith(
      step: SignInStep.phone,
      code: '',
      error: null,
      referenceNo: null,
    );
  }

  void restart() {
    _stopCountdown();
    state = const SignInState();
  }

  void _startCountdown(Duration window) {
    _stopCountdown();
    state = state.copyWith(secondsLeft: window.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.secondsLeft - 1;
      state = state.copyWith(secondsLeft: left < 0 ? 0 : left);
      if (left <= 0) timer.cancel();
    });
  }

  void _stopCountdown() {
    _ticker?.cancel();
    _ticker = null;
  }

  static String _digits(String value, int max) {
    final only = value.replaceAll(RegExp(r'\D'), '');
    return only.length > max ? only.substring(0, max) : only;
  }
}

final signInViewModelProvider =
    NotifierProvider<SignInViewModel, SignInState>(SignInViewModel.new);
