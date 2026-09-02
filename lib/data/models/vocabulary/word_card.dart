import 'package:json_annotation/json_annotation.dart';

part 'word_card.g.dart';

/// A sentence the word lives in, and what it says in Bangla.
@JsonSerializable(createToJson: false)
class WordExample {
  const WordExample({required this.en, required this.bn});

  factory WordExample.fromJson(Map<String, dynamic> json) =>
      _$WordExampleFromJson(json);

  final String en;
  final String bn;
}

/// One word, taught (SPEC §8).
///
/// Only [word], [bn] and [example] are required. The rest appear when the
/// word actually needs them — spec's own warning is against information
/// overload, and a card padded with empty sections teaches the learner to
/// skim past the sections that matter.
@JsonSerializable(createToJson: false)
class WordCard {
  const WordCard({
    required this.word,
    required this.bn,
    required this.example,
    this.pos,
    this.usage,
    this.synonyms = const [],
    this.antonyms = const [],
    this.collocations = const [],
  });

  factory WordCard.fromJson(Map<String, dynamic> json) =>
      _$WordCardFromJson(json);

  final String word;

  /// Bangla meaning.
  final String bn;

  final WordExample example;

  /// Part of speech, when it changes how the word is used.
  final String? pos;

  /// The shape the word takes, e.g. `reluctant + to + verb`.
  final String? usage;

  final List<String> synonyms;
  final List<String> antonyms;

  /// Pairings a learner would not guess, e.g. `reluctant to agree`.
  final List<String> collocations;
}
