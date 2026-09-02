// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_level.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LevelSubSkill _$LevelSubSkillFromJson(Map<String, dynamic> json) =>
    LevelSubSkill(
      id: json['id'] as String,
      preAssessmentBank: (json['preAssessmentBank'] as List<dynamic>)
          .map((e) => VocabQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      postAssessmentBank: (json['postAssessmentBank'] as List<dynamic>)
          .map((e) => VocabQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

VocabLevel _$VocabLevelFromJson(Map<String, dynamic> json) => VocabLevel(
  level: (json['level'] as num).toInt(),
  title: json['title'] as String,
  summary: json['summary'] as String,
  subSkills: (json['subSkills'] as List<dynamic>)
      .map((e) => LevelSubSkill.fromJson(e as Map<String, dynamic>))
      .toList(),
  chunks: (json['chunks'] as List<dynamic>)
      .map((e) => VocabChunk.fromJson(e as Map<String, dynamic>))
      .toList(),
);
