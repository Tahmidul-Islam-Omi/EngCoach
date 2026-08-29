import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

/// Who is signed in, and for how long.
///
/// Firebase Auth is the store: it persists a refresh token in Android's app
/// storage and restores the session on launch, which is why a subscriber
/// signs in once and then never sees the phone screen again. Nothing here
/// writes its own copy of that.
abstract interface class SessionService {
  /// The signed-in learner's phone number, or null. This is the Firebase
  /// uid — `firebase_token.php` mints the token with the number as uid.
  String? get currentPhone;

  /// Emits on sign-in and sign-out, and once at startup with the restored
  /// session. The router listens to this.
  Stream<String?> phoneChanges();

  /// Exchanges the token from bdapps for a Firebase session.
  ///
  /// Throws [AuthFailure] if the exchange fails. bdapps has already verified
  /// the learner by this point, so a failure here means Firestore is out of
  /// reach — not that sign-in was refused.
  Future<void> signIn(Session session);

  Future<void> signOut();
}

class FirebaseSessionService implements SessionService {
  FirebaseSessionService(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentPhone => _auth.currentUser?.uid;

  @override
  Stream<String?> phoneChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Future<void> signIn(Session session) async {
    final token = session.firebaseToken;

    if (token == null) {
      // The server could not read its service-account key. Worth naming
      // precisely rather than as a generic failure: everything else worked.
      throw const AuthFailure(
        "Signed in, but your progress can't be saved yet.",
      );
    }

    try {
      await _auth.signInWithCustomToken(token);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(
        e.code == 'invalid-custom-token' || e.code == 'custom-token-mismatch'
            ? "Signed in, but your progress can't be saved yet."
            : "Signed in, but syncing isn't available right now.",
      );
    } catch (_) {
      // A dropped connection surfaces as a PlatformException, not a
      // FirebaseAuthException. Uncaught, it would escape as an unhandled
      // async error and leave the sign-in screen stuck on its spinner.
      throw const AuthFailure(
        "Signed in, but syncing isn't available right now.",
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

final sessionServiceProvider = Provider<SessionService>(
  (ref) => FirebaseSessionService(FirebaseAuth.instance),
);

/// The signed-in phone number, or null. Null while the stored session is
/// still being restored, so callers must tolerate a brief null at startup.
final signedInPhoneProvider = StreamProvider<String?>(
  (ref) => ref.watch(sessionServiceProvider).phoneChanges(),
);
