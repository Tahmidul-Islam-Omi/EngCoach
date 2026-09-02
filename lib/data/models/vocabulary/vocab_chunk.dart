import 'package:json_annotation/json_annotation.dart';

import 'vocab_question.dart';
import 'word_card.dart';

part 'vocab_chunk.g.dart';

/// A handful of words, then questions on those words (SPEC §9, §11).
///
/// The chunk is the unit of learning, not the level: thirty cards followed by
/// twenty questions asks the learner to hold everything at once, while five
/// cards followed by five questions has them retrieving a word minutes after
/// meeting it. Practice length is authored per chunk rather than fixed,
/// because a chunk on phrasal verbs earns more questions than one on plurals.
@JsonSerializable(createToJson: false)
class VocabChunk {
  const VocabChunk({
    required this.id,
    required this.subSkillId,
    required this.title,
    required this.words,
    required this.practice,
  });

  factory VocabChunk.fromJson(Map<String, dynamic> json) =>
      _$VocabChunkFromJson(json);

  final String id;

  /// The subskill this chunk is here to fix. A learner only sees the chunks
  /// for subskills their check marked weak (SPEC §7).
  final String subSkillId;

  final String title;
  final List<WordCard> words;
  final List<VocabQuestion> practice;
}
