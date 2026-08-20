// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lesson _$LessonFromJson(Map<String, dynamic> json) => Lesson(
  id: json['id'] as String,
  subSkillId: json['subSkillId'] as String,
  title: json['title'] as String,
  blocks: Lesson._blocksFromJson(json['blocks'] as List),
  practice: (json['practice'] as List<dynamic>)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList(),
);
