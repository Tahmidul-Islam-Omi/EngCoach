import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/topic.dart';

/// Reads authored curriculum.
///
/// Implementations differ only in where the JSON comes from — today the
/// bundled asset, later Firestore. Nothing above this interface changes when
/// that swaps over.
abstract interface class ContentRepository {
  /// Topics in a section, ordered as authored.
  Future<List<Topic>> topicsForSection(String section);

  Future<Topic> topicById(String id);
}

/// Reads the JSON shipped inside the APK.
///
/// Everything is parsed once on first use and held in memory: the whole
/// curriculum is small, and re-parsing on every screen would be wasteful.
class AssetContentRepository implements ContentRepository {
  AssetContentRepository(this._bundle);

  final AssetBundle _bundle;
  Future<List<Topic>>? _cache;

  static const _prefix = 'content/';

  Future<List<Topic>> _load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final paths =
        manifest
            .listAssets()
            .where((p) => p.startsWith(_prefix) && p.endsWith('.json'))
            .toList()
          ..sort();

    final topics = <Topic>[];
    for (final path in paths) {
      final raw = await _bundle.loadString(path);
      topics.add(Topic.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    topics.sort((a, b) => a.order.compareTo(b.order));
    return topics;
  }

  Future<List<Topic>> _all() => _cache ??= _load();

  @override
  Future<List<Topic>> topicsForSection(String section) async =>
      (await _all()).where((t) => t.section == section).toList();

  @override
  Future<Topic> topicById(String id) async =>
      (await _all()).firstWhere((t) => t.id == id);
}

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => AssetContentRepository(rootBundle),
);

/// Topics in a section, for the topic-list screen.
final sectionTopicsProvider = FutureProvider.family<List<Topic>, String>((
  ref,
  section,
) {
  return ref.watch(contentRepositoryProvider).topicsForSection(section);
});

/// One topic, for the overview and everything downstream.
final topicProvider = FutureProvider.family<Topic, String>((ref, id) {
  return ref.watch(contentRepositoryProvider).topicById(id);
});
