// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Feedback _$FeedbackFromJson(Map<String, dynamic> json) =>
    Feedback(en: json['en'] as String, bn: json['bn'] as String);

QuestionOption _$QuestionOptionFromJson(Map<String, dynamic> json) =>
    QuestionOption(
      id: json['id'] as String,
      text: json['text'] as String,
      correct: json['correct'] as bool,
      feedback: json['feedback'] == null
          ? null
          : Feedback.fromJson(json['feedback'] as Map<String, dynamic>),
    );

Question _$QuestionFromJson(Map<String, dynamic> json) => Question(
  id: json['id'] as String,
  rule: json['rule'] as String,
  instruction: json['instruction'] as String,
  prompt: json['prompt'] as String,
  options: (json['options'] as List<dynamic>)
      .map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
      .toList(),
);
