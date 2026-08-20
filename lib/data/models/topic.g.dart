// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssessmentConfig _$AssessmentConfigFromJson(Map<String, dynamic> json) =>
    AssessmentConfig(
      questionsPerSubSkill: (json['questionsPerSubSkill'] as num).toInt(),
      qualifyingScore: (json['qualifyingScore'] as num).toInt(),
    );

SubSkill _$SubSkillFromJson(Map<String, dynamic> json) => SubSkill(
  id: json['id'] as String,
  title: json['title'] as String,
  preAssessmentBank: (json['preAssessmentBank'] as List<dynamic>)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList(),
  postAssessmentBank: (json['postAssessmentBank'] as List<dynamic>)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Topic _$TopicFromJson(Map<String, dynamic> json) => Topic(
  id: json['id'] as String,
  section: json['section'] as String,
  order: (json['order'] as num).toInt(),
  title: json['title'] as String,
  summary: json['summary'] as String,
  whyThisTopic: json['whyThisTopic'] as String,
  assessmentConfig: AssessmentConfig.fromJson(
    json['assessmentConfig'] as Map<String, dynamic>,
  ),
  subSkills: (json['subSkills'] as List<dynamic>)
      .map((e) => SubSkill.fromJson(e as Map<String, dynamic>))
      .toList(),
  lessons: (json['lessons'] as List<dynamic>)
      .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
      .toList(),
);
