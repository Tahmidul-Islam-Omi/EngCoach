import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vocabulary/vocab_course.dart';
import '../models/vocabulary/vocab_level.dart';

/// Reads the authored vocabulary curriculum.
///
/// Split from [ContentRepository] rather than folded into it: grammar is a
/// list of topics, vocabulary is a ladder of levels, and one interface
/// pretending to serve both would have to return the union of two shapes.
abstract interface class VocabularyRepository {
  /// The subskill registry and the ladder thresholds.
  Future<VocabCourse> course();

  /// One rung, by its 1-based number.
  Future<VocabLevel> level(int level);
}

/// Reads the JSON shipped inside the APK.
///
/// `course.json` is small and needed on every screen, so it is cached whole.
/// Levels are cached one at a time as they are opened: a learner works
/// through a single level, and parsing the other three costs memory to no end.
class AssetVocabularyRepository implements VocabularyRepository {
  AssetVocabularyRepository(this._bundle);

  final AssetBundle _bundle;

  static const _dir = 'content/vocabulary/';

  Future<VocabCourse>? _course;
  final _levels = <int, Future<VocabLevel>>{};

  Future<Map<String, dynamic>> _read(String file) async =>
      jsonDecode(await _bundle.loadString('$_dir$file'))
          as Map<String, dynamic>;

  @override
  Future<VocabCourse> course() =>
      _course ??= _read('course.json').then(VocabCourse.fromJson);

  @override
  Future<VocabLevel> level(int level) =>
      _levels[level] ??= _read('level_$level.json').then(VocabLevel.fromJson);
}

final vocabularyRepositoryProvider = Provider<VocabularyRepository>(
  (ref) => AssetVocabularyRepository(rootBundle),
);

/// The subskills and the ladder rules — needed wherever a subskill is named.
final vocabCourseProvider = FutureProvider<VocabCourse>((ref) {
  return ref.watch(vocabularyRepositoryProvider).course();
});

/// One level's questions and chunks.
final vocabLevelProvider = FutureProvider.family<VocabLevel, int>((ref, level) {
  return ref.watch(vocabularyRepositoryProvider).level(level);
});
