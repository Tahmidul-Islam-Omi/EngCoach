// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_chunk.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VocabChunk _$VocabChunkFromJson(Map<String, dynamic> json) => VocabChunk(
  id: json['id'] as String,
  subSkillId: json['subSkillId'] as String,
  title: json['title'] as String,
  words: (json['words'] as List<dynamic>)
      .map((e) => WordCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  practice: (json['practice'] as List<dynamic>)
      .map((e) => VocabQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
);
