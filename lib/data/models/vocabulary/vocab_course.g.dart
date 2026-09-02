// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_course.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VocabSubSkill _$VocabSubSkillFromJson(Map<String, dynamic> json) =>
    VocabSubSkill(id: json['id'] as String, title: json['title'] as String);

LadderConfig _$LadderConfigFromJson(Map<String, dynamic> json) => LadderConfig(
  questionsPerSubSkill: (json['questionsPerSubSkill'] as num).toInt(),
  advanceAt: (json['advanceAt'] as num).toInt(),
  probeAt: (json['probeAt'] as num).toInt(),
  probeSize: (json['probeSize'] as num).toInt(),
  probeAdvanceAt: (json['probeAdvanceAt'] as num).toInt(),
  topLevel: (json['topLevel'] as num).toInt(),
);

VocabCourse _$VocabCourseFromJson(Map<String, dynamic> json) => VocabCourse(
  subSkills: (json['subSkills'] as List<dynamic>)
      .map((e) => VocabSubSkill.fromJson(e as Map<String, dynamic>))
      .toList(),
  ladder: LadderConfig.fromJson(json['ladder'] as Map<String, dynamic>),
);
