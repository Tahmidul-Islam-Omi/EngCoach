// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VocabQuestion _$VocabQuestionFromJson(Map<String, dynamic> json) =>
    VocabQuestion(
      id: json['id'] as String,
      type: $enumDecode(_$VocabQuestionTypeEnumMap, json['type']),
      instruction: json['instruction'] as String,
      prompt: json['prompt'] as String,
      options: (json['options'] as List<dynamic>)
          .map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      tests: json['tests'] as String?,
    );

const _$VocabQuestionTypeEnumMap = {
  VocabQuestionType.meaning: 'meaning',
  VocabQuestionType.contextual: 'contextual',
  VocabQuestionType.usage: 'usage',
  VocabQuestionType.synonymAntonym: 'synonym_antonym',
  VocabQuestionType.collocation: 'collocation',
  VocabQuestionType.recall: 'recall',
};
