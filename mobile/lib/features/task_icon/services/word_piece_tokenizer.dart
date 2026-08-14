import 'dart:typed_data';

class TokenizedTaskTitle {
  const TokenizedTaskTitle({
    required this.inputIds,
    required this.attentionMask,
    required this.tokenTypeIds,
  });

  final Int64List inputIds;
  final Int64List attentionMask;
  final Int64List tokenTypeIds;
}

class WordPieceTokenizer {
  WordPieceTokenizer._(this._vocabulary)
    : _unknownId = _requiredId(_vocabulary, '[UNK]'),
      _classificationId = _requiredId(_vocabulary, '[CLS]'),
      _separatorId = _requiredId(_vocabulary, '[SEP]'),
      _paddingId = _requiredId(_vocabulary, '[PAD]');

  factory WordPieceTokenizer.fromVocabularyText(String source) {
    final vocabulary = <String, int>{};
    final lines = source.split(RegExp(r'\r?\n'));
    for (var index = 0; index < lines.length; index++) {
      final token = lines[index];
      if (token.isNotEmpty) vocabulary[token] = index;
    }
    return WordPieceTokenizer._(vocabulary);
  }

  final Map<String, int> _vocabulary;
  final int _unknownId;
  final int _classificationId;
  final int _separatorId;
  final int _paddingId;

  static int _requiredId(Map<String, int> vocabulary, String token) {
    final id = vocabulary[token];
    if (id == null) throw FormatException('Tokenizer vocabulary misses $token');
    return id;
  }

  TokenizedTaskTitle encode(String text, {required int maxLength}) {
    if (maxLength < 3) throw ArgumentError.value(maxLength, 'maxLength');
    final pieces = <int>[_classificationId];
    for (final token in _basicTokenize(text)) {
      final remaining = maxLength - pieces.length - 1;
      if (remaining <= 0) break;
      final tokenPieces = _wordPiece(token);
      pieces.addAll(
        tokenPieces.length <= remaining
            ? tokenPieces
            : tokenPieces.take(remaining),
      );
    }
    pieces.add(_separatorId);

    final inputIds = Int64List(maxLength);
    final attentionMask = Int64List(maxLength);
    final tokenTypeIds = Int64List(maxLength);
    for (var index = 0; index < maxLength; index++) {
      if (index < pieces.length) {
        inputIds[index] = pieces[index];
        attentionMask[index] = 1;
      } else {
        inputIds[index] = _paddingId;
      }
    }
    return TokenizedTaskTitle(
      inputIds: inputIds,
      attentionMask: attentionMask,
      tokenTypeIds: tokenTypeIds,
    );
  }

  List<int> _wordPiece(String token) {
    final codePoints = token.runes.toList(growable: false);
    if (codePoints.length > 100) return [_unknownId];
    final output = <int>[];
    var start = 0;
    while (start < codePoints.length) {
      int? matchedId;
      var matchedEnd = codePoints.length;
      while (start < matchedEnd) {
        final value = String.fromCharCodes(
          codePoints.sublist(start, matchedEnd),
        );
        final piece = start == 0 ? value : '##$value';
        matchedId = _vocabulary[piece];
        if (matchedId != null) break;
        matchedEnd--;
      }
      if (matchedId == null) return [_unknownId];
      output.add(matchedId);
      start = matchedEnd;
    }
    return output;
  }

  List<String> _basicTokenize(String text) {
    final output = <String>[];
    final current = <int>[];

    void flush() {
      if (current.isEmpty) return;
      output.add(String.fromCharCodes(current));
      current.clear();
    }

    for (final codePoint in text.runes) {
      if (_isControl(codePoint)) continue;
      if (_isWhitespace(codePoint)) {
        flush();
      } else if (_isCjk(codePoint) || _isPunctuation(codePoint)) {
        flush();
        output.add(String.fromCharCode(codePoint));
      } else {
        current.add(codePoint);
      }
    }
    flush();
    return output;
  }

  bool _isWhitespace(int value) =>
      value == 0x20 ||
      value == 0x09 ||
      value == 0x0A ||
      value == 0x0D ||
      value == 0x00A0 ||
      value == 0x1680 ||
      (value >= 0x2000 && value <= 0x200A) ||
      value == 0x2028 ||
      value == 0x2029 ||
      value == 0x202F ||
      value == 0x205F ||
      value == 0x3000;

  bool _isControl(int value) =>
      value == 0 ||
      value == 0xFFFD ||
      (value < 0x20 && !_isWhitespace(value)) ||
      (value >= 0x7F && value <= 0x9F);

  bool _isPunctuation(int value) =>
      (value >= 33 && value <= 47) ||
      (value >= 58 && value <= 64) ||
      (value >= 91 && value <= 96) ||
      (value >= 123 && value <= 126) ||
      (value >= 0x2000 && value <= 0x206F) ||
      (value >= 0x2E00 && value <= 0x2E7F) ||
      (value >= 0x3001 && value <= 0x303F) ||
      (value >= 0xFE10 && value <= 0xFE1F) ||
      (value >= 0xFE30 && value <= 0xFE4F) ||
      (value >= 0xFF01 && value <= 0xFF0F) ||
      (value >= 0xFF1A && value <= 0xFF20) ||
      (value >= 0xFF3B && value <= 0xFF40) ||
      (value >= 0xFF5B && value <= 0xFF65);

  bool _isCjk(int value) =>
      (value >= 0x4E00 && value <= 0x9FFF) ||
      (value >= 0x3400 && value <= 0x4DBF) ||
      (value >= 0x20000 && value <= 0x2A6DF) ||
      (value >= 0x2A700 && value <= 0x2B73F) ||
      (value >= 0x2B740 && value <= 0x2B81F) ||
      (value >= 0x2B820 && value <= 0x2CEAF) ||
      (value >= 0xF900 && value <= 0xFAFF) ||
      (value >= 0x2F800 && value <= 0x2FA1F);
}
