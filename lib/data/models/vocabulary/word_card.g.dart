// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WordExample _$WordExampleFromJson(Map<String, dynamic> json) =>
    WordExample(en: json['en'] as String, bn: json['bn'] as String);

WordCard _$WordCardFromJson(Map<String, dynamic> json) => WordCard(
  word: json['word'] as String,
  bn: json['bn'] as String,
  example: WordExample.fromJson(json['example'] as Map<String, dynamic>),
  pos: json['pos'] as String?,
  usage: json['usage'] as String?,
  synonyms:
      (json['synonyms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  antonyms:
      (json['antonyms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  collocations:
      (json['collocations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);
