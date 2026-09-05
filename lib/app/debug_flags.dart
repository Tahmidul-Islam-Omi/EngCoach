import 'package:flutter/foundation.dart';

/// Testing aids, compiled out of release builds.
///
/// Every flag here is `kDebugMode && …`, so a release APK ignores them whatever
/// they are set to. That is deliberate: the cost of forgetting to switch one
/// off should be zero, not a shipped app that shows learners the answers.
abstract final class DebugFlags {
  /// Set to false to walk the app exactly as a learner sees it.
  static const _wanted = true;

  /// Marks the right answer on every question with a dot, so a whole flow can
  /// be walked without reading it.
  static const revealAnswers = kDebugMode && _wanted;
}
