import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/features/task_icon/services/word_piece_tokenizer.dart';
import 'package:florien/features/task_icon/data/category_embedding_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches the official cased LEALLA tokenizer for Turkish', () async {
    final vocabulary = await rootBundle.loadString(
      'assets/task_icons/vocab.txt',
    );
    final tokenizer = WordPieceTokenizer.fromVocabularyText(vocabulary);

    final result = tokenizer.encode('Arabayı servise götür', maxLength: 12);

    expect(result.inputIds, [
      101,
      124051,
      24267,
      389538,
      372949,
      38017,
      102,
      0,
      0,
      0,
      0,
      0,
    ]);
    expect(result.attentionMask, [1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]);
  });

  test('splits CJK characters like the official tokenizer', () async {
    final vocabulary = await rootBundle.loadString(
      'assets/task_icons/vocab.txt',
    );
    final tokenizer = WordPieceTokenizer.fromVocabularyText(vocabulary);

    final result = tokenizer.encode('母にプレゼントを買う', maxLength: 12);

    expect(result.inputIds, [
      101,
      7200,
      3711,
      240767,
      17159,
      10328,
      3675,
      102,
      0,
      0,
      0,
      0,
    ]);
  });

  test('loads and validates all 100 precomputed category groups', () async {
    final index = AssetCategoryEmbeddingIndex();
    await index.initialize();
    final query = Float32List(128)..first = 1;

    final scores = index.score(query);

    expect(scores, hasLength(100));
    expect(
      scores.first.confidence,
      greaterThanOrEqualTo(scores.last.confidence),
    );
  });
}
