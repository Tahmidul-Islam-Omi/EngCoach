import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// A signed-in learner.
///
/// The phone number IS the identity — there is no separate user id. It is
/// also the Firebase uid, so Firestore rules can compare `request.auth.uid`
/// against the document path directly.
class Session {
  const Session({
    required this.phone,
    required this.isSubscribed,
    this.firebaseToken,
  });

  final String phone;

  /// True while bdapps is charging. Counts the ~40-50s "INITIAL CHARGING
  /// PENDING" window, because the charge has already been accepted and
  /// locking a new subscriber out during it would be wrong.
  final bool isSubscribed;

  /// Exchanged for a Firebase session by the auth layer. Null when the
  /// server could not sign one — the learner is still signed in with bdapps,
  /// but nothing can reach Firestore.
  final String? firebaseToken;
}

/// What starting sign-in led to.
///
/// Sealed so the view model must handle both — an existing subscriber never
/// sees a code, and a new one always does.
sealed class SignInStart {
  const SignInStart();
}

/// The number was already subscribed, so there was nothing to verify.
class AlreadySignedIn extends SignInStart {
  const AlreadySignedIn(this.session);

  final Session session;
}

/// A new number: bdapps sent a code, and [referenceNo] must come back with it.
class CodeSent extends SignInStart {
  const CodeSent({required this.referenceNo, required this.resendAfter});

  final String referenceNo;
  final Duration resendAfter;
}

/// Something went wrong. Carries wording the screen can show as-is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Signs learners in against bdapps.
abstract interface class AuthRepository {
  /// Decides which flow applies and starts it.
  Future<SignInStart> start(String phone);

  /// Finishes the new-subscriber flow. This is what subscribes the learner
  /// and starts the daily charge.
  Future<Session> verify({
    required String phone,
    required String code,
    required String referenceNo,
  });

  /// Whether the number is subscribed right now. Read live rather than
  /// cached: people unsubscribe by texting STOP to 21213, entirely outside
  /// the app.
  Future<bool> isSubscribed(String phone);

  /// Ends the subscription and the daily charge.
  ///
  /// Access stops immediately — there is no paid period left to run out.
  /// Throws [AuthFailure] if bdapps refused, so the caller never reports
  /// success for a subscription that is still charging.
  Future<void> unsubscribe(String phone);
}

/// Talks to the PHP endpoints on cPanel.
///
/// Those hold the bdapps application password and the Firebase
/// service-account key, neither of which can ship inside an APK — anyone can
/// unzip one and read its strings.
class BdappsAuthRepository implements AuthRepository {
  BdappsAuthRepository({http.Client? client, this.baseUrl = _defaultBaseUrl})
      : _client = client ?? http.Client();

  static const _defaultBaseUrl = 'https://bdappsdigitalapps.com/engcoach';

  /// bdapps itself takes a couple of seconds; a slow mobile connection adds
  /// to that, so this is generous rather than snappy.
  static const _timeout = Duration(seconds: 30);

  /// Matches the resend lock the sign-in screen shows.
  static const _resendAfter = Duration(seconds: 45);

  final http.Client _client;
  final String baseUrl;

  @override
  Future<SignInStart> start(String phone) async {
    final status = await _post('check_subscription.php', {'user_mobile': phone});

    if (status['isSubscribed'] == true) {
      return AlreadySignedIn(
        Session(
          phone: (status['phone'] as String?) ?? phone,
          isSubscribed: true,
          firebaseToken: status['firebaseToken'] as String?,
        ),
      );
    }

    final sent = await _post('send_otp.php', {'user_mobile': phone});

    final referenceNo = (sent['referenceNo'] as String?) ?? '';
    if (sent['success'] != true || referenceNo.isEmpty) {
      throw AuthFailure(_startFailure(sent));
    }

    return CodeSent(referenceNo: referenceNo, resendAfter: _resendAfter);
  }

  @override
  Future<Session> verify({
    required String phone,
    required String code,
    required String referenceNo,
  }) async {
    final result = await _post('verify_otp.php', {
      'Otp': code,
      'referenceNo': referenceNo,
    });

    final statusCode = (result['statusCode'] as String?)?.toUpperCase() ?? '';

    if (statusCode != 'S1000') {
      // A wrong code does not invalidate the reference — verified against the
      // live API — so the screen can let them retype without a new SMS.
      throw AuthFailure(
        statusCode == 'E1850'
            ? 'That code is not right. Check the digits and try again.'
            : (result['statusDetail'] as String?) ??
                'That code could not be checked. Try again.',
      );
    }

    return Session(
      phone: (result['phone'] as String?) ?? phone,
      isSubscribed: result['isSubscribed'] == true,
      firebaseToken: result['firebaseToken'] as String?,
    );
  }

  @override
  Future<bool> isSubscribed(String phone) async {
    final status = await _post('check_subscription.php', {'user_mobile': phone});
    return status['isSubscribed'] == true;
  }

  @override
  Future<void> unsubscribe(String phone) async {
    final result = await _post('unsubscribe.php', {'user_mobile': phone});

    // bdapps answers UNREGISTERED for a number that was already off, which
    // is the outcome asked for either way.
    final done = result['success'] == true ||
        (result['subscriptionStatus'] as String?)?.toUpperCase() ==
            'UNREGISTERED';

    if (!done) {
      throw AuthFailure(
        (result['statusDetail'] as String?) ??
            (result['error'] as String?) ??
            "Couldn't unsubscribe just now. Please try again.",
      );
    }
  }

  /// bdapps reports failures inside a 200 body, so the wording comes from the
  /// payload rather than the status line.
  String _startFailure(Map<String, dynamic> body) {
    final code = (body['statusCode'] as String?)?.toUpperCase() ?? '';
    if (code == 'E1351') {
      // Only reachable if a subscription settles between the two calls.
      return 'This number is already subscribed. Try again.';
    }
    return (body['message'] as String?) ??
        (body['statusDetail'] as String?) ??
        "The code couldn't be sent. Try again in a moment.";
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> fields,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse('$baseUrl/$path'), body: fields)
          .timeout(_timeout);
    } catch (_) {
      // Every transport fault reads the same to a learner on mobile data.
      throw const AuthFailure(
        "Couldn't reach the network. Check your connection and try again.",
      );
    }

    if (response.statusCode != 200) {
      throw const AuthFailure('Something went wrong. Try again in a moment.');
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthFailure('Something went wrong. Try again in a moment.');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => BdappsAuthRepository(),
);
