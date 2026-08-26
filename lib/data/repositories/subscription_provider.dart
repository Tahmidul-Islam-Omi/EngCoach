import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'session_repository.dart';

/// Whether the signed-in learner is currently paying.
///
/// Read live from bdapps rather than cached, because people unsubscribe
/// outside the app entirely — by texting STOP engcoach to 21213, or through
/// the USSD menu. A flag stored at sign-in would keep saying "subscribed"
/// long after the charging stopped.
///
/// Null phone means signed out, which is not the same as unsubscribed: the
/// router sends those to sign-in instead.
final subscriptionProvider = FutureProvider<bool>(
  // Riverpod retries a failed provider on its own, with backoff. Not here:
  // the failure screen offers an explicit "Try again", and a silent loop
  // would keep calling bdapps over the mobile connection that just failed.
  retry: (_, _) => null,
  (ref) async {
    // Pattern-matched rather than read as a nullable, so "still restoring
    // the session" is not mistaken for "signed out".
    final phone = switch (ref.watch(signedInPhoneProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (phone == null) return false;

    return ref.watch(authRepositoryProvider).isSubscribed(phone);
  },
);
