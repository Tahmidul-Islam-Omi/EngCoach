import 'dart:convert';
import 'dart:io';

import 'package:engcoach/data/models/topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every authored topic parses into the model', () {
    final files = Directory(
      'content/grammar',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

    expect(files, isNotEmpty, reason: 'no topic JSON found');

    for (final file in files) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final topic = Topic.fromJson(json);
      expect(topic.subSkills, isNotEmpty);
      expect(topic.lessons, isNotEmpty);
      for (final s in topic.subSkills) {
        expect(topic.lessonFor(s.id), isNotNull);
      }
    }
  });
}
