import 'package:florien/features/task_icon/data/task_keywords.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';

/// Fast on-device matcher over [taskCategoryKeywords].
///
/// Independent of Flutter widgets and IconPark. Safe to run while typing.
class TaskIconLexicon {
  const TaskIconLexicon._();

  static List<(String, TaskCategory)>? _rankedKeywords;

  static TaskCategory? match(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return null;

    final tokens = normalized.split(' ');
    TaskCategory? best;
    var bestScore = 0;

    for (final rule in taskKeywordTokenGroups) {
      if (rule.$1.every((token) => _hasToken(tokens, token))) {
        final score = 1000 + rule.$1.fold<int>(0, (sum, t) => sum + t.length);
        if (score > bestScore) {
          bestScore = score;
          best = rule.$2;
        }
      }
    }

    for (final item in _keywordsByLength()) {
      if (item.$1.length < bestScore) break;
      if (_containsKeyword(normalized, tokens, item.$1) &&
          item.$1.length > bestScore) {
        bestScore = item.$1.length;
        best = item.$2;
      }
    }

    if (best != null) return best;

    for (final token in tokens) {
      for (final stem in taskKeywordVerbStems) {
        if (_matchesTurkishVerb(token, stem.$1)) return stem.$2;
      }
    }
    return null;
  }

  static List<(String, TaskCategory)> _keywordsByLength() {
    final cached = _rankedKeywords;
    if (cached != null) return cached;
    final items = <(String, TaskCategory)>[];
    for (final entry in taskCategoryKeywords.entries) {
      for (final raw in entry.value.all) {
        final folded = normalize(raw);
        if (folded.length >= 3) items.add((folded, entry.key));
      }
    }
    items.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return _rankedKeywords = items;
  }

  static bool _containsKeyword(
    String normalized,
    List<String> tokens,
    String keyword,
  ) {
    if (keyword.contains(' ')) {
      return normalized == keyword ||
          normalized.startsWith('$keyword ') ||
          normalized.endsWith(' $keyword') ||
          normalized.contains(' $keyword ');
    }
    return tokens.any((token) => token == keyword);
  }

  static bool _hasToken(List<String> tokens, String needle) {
    return tokens.any((token) {
      if (token == needle) return true;
      final extra = token.length - needle.length;
      return extra > 0 && extra <= 3 && token.startsWith(needle);
    });
  }

  /// `koşacağım` → stem `kos` + future suffix `acagim`.
  static bool _matchesTurkishVerb(String token, String stem) {
    if (token == stem) return true;
    if (!token.startsWith(stem) || token.length <= stem.length) return false;
    var rest = token.substring(stem.length);
    if (_verbalSuffixes.contains(rest)) return true;
    if (rest.startsWith('y') &&
        rest.length > 1 &&
        _verbalSuffixes.contains(rest.substring(1))) {
      return true;
    }
    return false;
  }

  static String normalize(String text) {
    final lower = text.trim().toLowerCase();
    final buffer = StringBuffer();
    var pendingSpace = false;
    for (final unit in lower.runes) {
      final folded = switch (unit) {
        0xE7 || 0xC7 => 99, // ç
        0x11F || 0x11E => 103, // ğ
        0x131 || 0x130 || 0x49 => 105, // ı/İ/I → i
        0x15F || 0x15E => 115, // ş
        0xFC || 0xDC => 117, // ü
        0xF6 || 0xD6 => 111, // ö
        0xE2 => 97, // â
        0xEE => 105, // î
        0xFB => 117, // û
        0xE9 || 0xE8 => 101, // é/è
        0xE0 => 97, // à
        0xF1 => 110, // ñ
        0xDF => 115, // ß → s (approx)
        _ => unit,
      };
      final isLetter = folded >= 97 && folded <= 122;
      final isDigit = folded >= 48 && folded <= 57;
      if (isLetter || isDigit) {
        if (pendingSpace && buffer.isNotEmpty) buffer.write(' ');
        buffer.writeCharCode(folded);
        pendingSpace = false;
      } else {
        pendingSpace = true;
      }
    }
    return buffer.toString();
  }
}

const _verbalSuffixes = {
  'acagim',
  'acaksin',
  'acak',
  'acagiz',
  'acaksiniz',
  'acaklar',
  'ecegim',
  'eceksin',
  'ecek',
  'ecegiz',
  'eceksiniz',
  'ecekler',
  'uyorum',
  'uyorsun',
  'uyor',
  'uyoruz',
  'uyorsunuz',
  'uyorlar',
  'iyorum',
  'iyorsun',
  'iyor',
  'iyoruz',
  'iyorsunuz',
  'iyorlar',
  'yorum',
  'yorsun',
  'yor',
  'yoruz',
  'tum',
  'tun',
  'tu',
  'tuk',
  'tunuz',
  'tular',
  'dum',
  'dun',
  'du',
  'duk',
  'mak',
  'mek',
  'maya',
  'meye',
  'ma',
  'me',
  'arim',
  'arsin',
  'ar',
  'ariz',
  'erim',
  'er',
  'cam',
  'cem',
  'ucam',
  'alim',
  'elim',
  'un',
  'u',
  'uya',
  'ye',
  'ya',
};
