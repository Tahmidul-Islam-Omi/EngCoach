import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/progress_repository.dart';
import '../data/services/session_service.dart';

/// Work that happens because the app is running, not because a screen asked.
///
/// Stamps `lastSeenAt` — and creates the user document on a first visit —
/// whenever a session exists.
///
/// A provider rather than a `ref.listen` in a widget: WidgetRef.listen only
/// reports *changes*, so a session that had already resolved by the time the
/// widget registered would never be stamped at all. Watching re-runs on the
/// first value as well as every later one.
///
/// It lives here rather than beside the repository because it is a startup
/// concern that happens to write data, not a way of reading it.
final visitStampProvider = Provider<void>((ref) {
  final phone = ref.watch(signedInPhoneProvider).value;
  if (phone == null) return;

  final repository = ref.watch(progressRepositoryProvider);
  // Off the build turn, and never surfaced: a missed timestamp is not worth
  // interrupting anyone for. Caught rather than left unawaited — touch()
  // uses a transaction, which fails with no network, and an uncaught async
  // error would surface as a red screen in debug for nothing.
  Future<void>.microtask(() async {
    try {
      await repository.touch();
    } catch (_) {
      // Reported once Crashlytics is in.
    }
  });
});
