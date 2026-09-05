import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The running build, as "1.0.0 (1)".
///
/// Version and build number together, because they answer different halves of
/// the only question this is here for: when a learner reports something, the
/// version says which release and the build says which upload of it.
///
/// Kept separate from the rest of the profile so a platform channel that is
/// slow or unavailable cannot take the whole screen down with it.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});
